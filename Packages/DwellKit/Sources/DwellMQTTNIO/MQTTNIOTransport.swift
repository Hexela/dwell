// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellMQTT
import Foundation
import MQTTNIO
import NIOCore
import NIOPosix

/// Creates MQTTNIO-backed transports without exposing MQTTNIO to Dwell Core.
public struct MQTTNIOTransportFactory: MQTTTransportFactory {
    public init() {}

    public func makeTransport(
        configuration: BrokerConfiguration,
        lastWillPayload: Data
    ) async throws -> any MQTTTransport {
        MQTTNIOTransport(
            configuration: configuration,
            lastWillPayload: lastWillPayload
        )
    }
}

/// An MQTTNIO-backed connection isolated behind the Dwell transport protocol.
public actor MQTTNIOTransport: MQTTTransport {
    private let configuration: BrokerConfiguration
    private let lastWillPayload: Data
    private let client: MQTTClient
    private var listenerName: String?
    private var isShutdown = false

    /// Creates a transport for one connection attempt.
    public init(
        configuration: BrokerConfiguration,
        lastWillPayload: Data
    ) {
        let version: MQTTClient.Version
        switch configuration.protocolVersion {
        case .v3_1_1:
            version = .v3_1_1
        case .v5:
            version = .v5_0
        }

        self.configuration = configuration
        self.lastWillPayload = lastWillPayload
        client = MQTTClient(
            host: configuration.host,
            port: configuration.port,
            identifier: configuration.clientIdentifier,
            eventLoopGroupProvider: .shared(
                MultiThreadedEventLoopGroup.singleton
            ),
            configuration: MQTTClient.Configuration(
                version: version,
                userName: configuration.username,
                password: configuration.password,
                useSSL: configuration.usesTLS
            )
        )
    }

    public func connect() async throws {
        var willPayload = ByteBufferAllocator().buffer(
            capacity: lastWillPayload.count
        )
        willPayload.writeBytes(lastWillPayload)
        _ = try await client.connect(
            cleanSession: false,
            will: (
                topicName: configuration.statusTopic,
                payload: willPayload,
                qos: .atLeastOnce,
                retain: true
            )
        )
    }

    public func subscribe(to topicFilter: String) async throws {
        let acknowledgement = try await client.subscribe(
            to: [
                MQTTSubscribeInfo(
                    topicFilter: topicFilter,
                    qos: .atLeastOnce
                )
            ]
        )
        guard acknowledgement.returnCodes.allSatisfy({ $0 != .failure }) else {
            throw MQTTNIOTransportError.subscriptionRejected
        }
    }

    public func publish(
        _ payload: Data,
        to topic: String,
        retain: Bool
    ) async throws {
        var buffer = ByteBufferAllocator().buffer(capacity: payload.count)
        buffer.writeBytes(payload)
        try await client.publish(
            to: topic,
            payload: buffer,
            qos: .atLeastOnce,
            retain: retain
        )
    }

    public func incomingMessages() async
        -> AsyncThrowingStream<MQTTMessage, any Error>
    {
        let name = UUID().uuidString
        listenerName = name

        return AsyncThrowingStream { continuation in
            client.addPublishListener(named: name) { result in
                switch result {
                case .success(let publication):
                    var payload = publication.payload
                    let data =
                        payload.readData(length: payload.readableBytes) ?? Data()
                    continuation.yield(
                        MQTTMessage(
                            topic: publication.topicName,
                            payload: data,
                            qualityOfService: Int(publication.qos.rawValue),
                            isRetained: publication.retain,
                            isDuplicate: publication.dup
                        )
                    )
                case .failure:
                    continuation.finish(
                        throwing: MQTTNIOTransportError.receiveFailed
                    )
                }
            }
        }
    }

    public func disconnect() async {
        guard isShutdown == false else {
            return
        }
        isShutdown = true
        if let listenerName {
            client.removePublishListener(named: listenerName)
        }
        try? await client.disconnect()
        try? await client.shutdown()
        listenerName = nil
    }
}

/// Stable failures emitted by the MQTTNIO adapter.
public enum MQTTNIOTransportError: String, Error, Sendable {
    case notConnected = "not-connected"
    case receiveFailed = "receive-failed"
    case subscriptionRejected = "subscription-rejected"
}
