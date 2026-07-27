// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// Owns connection, subscription, validation, and reconnection for one broker.
public actor BrokerSession {
    public typealias StatusHandler = @Sendable (BrokerStatus) -> Void
    public typealias MessageHandler = @Sendable (InboundMessageResult) async -> Void

    private let configuration: BrokerConfiguration
    private let transportFactory: any MQTTTransportFactory
    private let pipeline: CanonicalMessagePipeline
    private let reconnectPolicy: ReconnectPolicy
    private let sleeper: any BrokerSleeper
    private let statusHandler: StatusHandler
    private let messageHandler: MessageHandler
    private var status = BrokerStatus(state: .disabled)
    private var activeTransport: (any MQTTTransport)?

    /// Creates a broker session.
    public init(
        configuration: BrokerConfiguration,
        transportFactory: any MQTTTransportFactory,
        pipeline: CanonicalMessagePipeline = CanonicalMessagePipeline(),
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy(),
        sleeper: any BrokerSleeper = ContinuousBrokerSleeper(),
        statusHandler: @escaping StatusHandler = { _ in },
        messageHandler: @escaping MessageHandler = { _ in }
    ) {
        self.configuration = configuration
        self.transportFactory = transportFactory
        self.pipeline = pipeline
        self.reconnectPolicy = reconnectPolicy
        self.sleeper = sleeper
        self.statusHandler = statusHandler
        self.messageHandler = messageHandler
    }

    /// Runs until cancellation, reconnecting after recoverable failures.
    public func run() async {
        var attempt: UInt = 0

        while Task.isCancelled == false {
            do {
                try await runConnectionAttempt()
                attempt = 0
            } catch is CancellationError {
                break
            } catch {
                attempt += 1
                updateStatus(
                    state: .reconnecting,
                    reconnectCount: status.reconnectCount + 1,
                    lastErrorCode: Self.errorCode(for: error)
                )

                do {
                    try await sleeper.sleep(
                        for: reconnectPolicy.delay(
                            forAttempt: attempt - 1,
                            jitterUnitInterval: Double.random(in: 0...1)
                        )
                    )
                } catch {
                    break
                }
            }
        }

        await activeTransport?.disconnect()
        activeTransport = nil
        updateStatus(state: .stopped)
    }

    /// Performs one complete connection attempt.
    public func runConnectionAttempt() async throws {
        updateStatus(state: status.reconnectCount == 0 ? .connecting : .reconnecting)
        let transport = try await transportFactory.makeTransport(
            configuration: configuration,
            lastWillPayload: Self.statusPayload(online: false)
        )
        activeTransport = transport

        do {
            try await transport.connect()
            try await transport.subscribe(to: configuration.canonicalTopicFilter)
            try await transport.publish(
                Self.statusPayload(online: true),
                to: configuration.statusTopic,
                retain: true
            )
            updateStatus(state: .online, lastErrorCode: nil)

            let publications = await transport.incomingMessages()
            for try await publication in publications {
                guard publication.topic != configuration.statusTopic else {
                    continue
                }
                let result = await pipeline.process(publication)
                record(result)
                await messageHandler(result)
            }

            throw BrokerSessionError.connectionClosed
        } catch {
            await transport.disconnect()
            activeTransport = nil
            throw error
        }
    }

    /// Publishes an outbound canonical message on the active connection.
    public func publish(_ payload: Data, to topic: String) async throws {
        guard let activeTransport else {
            throw BrokerSessionError.notConnected
        }
        try await activeTransport.publish(payload, to: topic, retain: false)
    }

    private func record(_ result: InboundMessageResult) {
        switch result {
        case .accepted:
            updateStatus(
                acceptedMessageCount: status.acceptedMessageCount + 1,
                lastMessageAt: Date()
            )
        case .duplicate:
            updateStatus(
                duplicateMessageCount: status.duplicateMessageCount + 1,
                lastMessageAt: Date()
            )
        case .rejected:
            updateStatus(
                rejectedMessageCount: status.rejectedMessageCount + 1,
                lastMessageAt: Date()
            )
        }
    }

    private func updateStatus(
        state: BrokerConnectionState? = nil,
        reconnectCount: UInt? = nil,
        acceptedMessageCount: UInt? = nil,
        duplicateMessageCount: UInt? = nil,
        rejectedMessageCount: UInt? = nil,
        lastMessageAt: Date? = nil,
        lastErrorCode: String?? = nil
    ) {
        status = BrokerStatus(
            state: state ?? status.state,
            reconnectCount: reconnectCount ?? status.reconnectCount,
            acceptedMessageCount: acceptedMessageCount ?? status.acceptedMessageCount,
            duplicateMessageCount: duplicateMessageCount ?? status.duplicateMessageCount,
            rejectedMessageCount: rejectedMessageCount ?? status.rejectedMessageCount,
            lastMessageAt: lastMessageAt ?? status.lastMessageAt,
            lastErrorCode: lastErrorCode ?? status.lastErrorCode
        )
        statusHandler(status)
    }

    private static func statusPayload(online: Bool) -> Data {
        Data(#"{"status":"\#(online ? "online" : "offline")"}"#.utf8)
    }

    private static func errorCode(for error: any Error) -> String {
        if let error = error as? BrokerSessionError {
            return error.rawValue
        }
        return "transport-error"
    }
}

/// Stable broker-session failures.
public enum BrokerSessionError: String, Error, Sendable {
    case connectionClosed = "connection-closed"
    case notConnected = "not-connected"
}
