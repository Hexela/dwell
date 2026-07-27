// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellMQTT
import Foundation
import Testing

@Suite("MQTT broker session")
struct BrokerSessionTests {
    @Test("Reconnect delay is exponential and bounded")
    func reconnectDelayIsBounded() {
        let policy = ReconnectPolicy(
            initialDelay: .seconds(1),
            maximumDelay: .seconds(10)
        )

        #expect(policy.delay(forAttempt: 0) == .seconds(1))
        #expect(policy.delay(forAttempt: 1) == .seconds(2))
        #expect(policy.delay(forAttempt: 4) == .seconds(10))
        #expect(policy.delay(forAttempt: 100) == .seconds(10))
        #expect(
            policy.delay(forAttempt: 0, jitterUnitInterval: 0)
                == .milliseconds(800)
        )
    }

    @Test("Canonical pipeline accepts once and rejects duplicate delivery")
    func canonicalPipelineDeduplicates() async throws {
        let pipeline = CanonicalMessagePipeline(deduplicationCapacity: 2)
        let publication = MQTTMessage(
            topic: "dwell/v1/i/home-a/device/sensor/component/main/state/sensor.temperature",
            payload: try fixture(named: "temperature"),
            qualityOfService: 1,
            isRetained: true,
            isDuplicate: false
        )

        guard case .accepted = await pipeline.process(publication) else {
            Issue.record("Expected the first publication to be accepted.")
            return
        }
        guard case .duplicate = await pipeline.process(publication) else {
            Issue.record("Expected the repeated message ID to be rejected.")
            return
        }
    }

    @Test("Oversized payload is rejected before JSON decoding")
    func oversizedPayloadIsRejected() async {
        let pipeline = CanonicalMessagePipeline(maximumPayloadSize: 8)
        let publication = MQTTMessage(
            topic: "dwell/v1/i/home-a/device/sensor/component/main/state/sensor.temperature",
            payload: Data(repeating: 0, count: 9),
            qualityOfService: 1,
            isRetained: false,
            isDuplicate: false
        )

        guard case .rejected(let code) = await pipeline.process(publication) else {
            Issue.record("Expected the oversized publication to be rejected.")
            return
        }
        #expect(code == "payload-too-large")
    }

    @Test("Connection attempt subscribes and publishes retained online status")
    func connectionAttemptEstablishesCanonicalSession() async throws {
        let transport = RecordingTransport()
        let session = BrokerSession(
            configuration: testConfiguration,
            transportFactory: FixedTransportFactory(transport: transport)
        )

        await #expect(throws: BrokerSessionError.connectionClosed) {
            try await session.runConnectionAttempt()
        }

        let record = await transport.record
        #expect(record.didConnect)
        #expect(record.subscriptions == ["dwell/v1/i/home-a/#"])
        #expect(record.publications.count == 1)
        #expect(record.publications.first?.topic == "dwell/v1/i/home-a/system/status")
        #expect(record.publications.first?.retain == true)
    }

    private var testConfiguration: BrokerConfiguration {
        BrokerConfiguration(
            host: "broker.example",
            port: 8883,
            clientIdentifier: "dwell-test",
            installationIdentifier: "home-a"
        )
    }

    private func fixture(named name: String) throws -> Data {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return try Data(
            contentsOf: root.appending(
                path: "Tests/Fixtures/MQTT/v1/valid/\(name).json"
            )
        )
    }
}

private struct FixedTransportFactory: MQTTTransportFactory {
    let transport: RecordingTransport

    func makeTransport(
        configuration: BrokerConfiguration,
        lastWillPayload: Data
    ) async throws -> any MQTTTransport {
        transport
    }
}

private actor RecordingTransport: MQTTTransport {
    struct Publication: Sendable {
        let topic: String
        let retain: Bool
    }

    struct Record: Sendable {
        var didConnect = false
        var subscriptions: [String] = []
        var publications: [Publication] = []
    }

    private(set) var record = Record()

    func connect() async throws {
        record.didConnect = true
    }

    func subscribe(to topicFilter: String) async throws {
        record.subscriptions.append(topicFilter)
    }

    func publish(
        _ payload: Data,
        to topic: String,
        retain: Bool
    ) async throws {
        record.publications.append(Publication(topic: topic, retain: retain))
    }

    func incomingMessages() async
        -> AsyncThrowingStream<MQTTMessage, any Error>
    {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func disconnect() async {}
}
