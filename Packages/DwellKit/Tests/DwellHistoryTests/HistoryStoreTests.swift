// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellHistory
import DwellDomain
import DwellMQTT
import DwellSchemas
import Foundation
import Testing

@Suite("Operational history store")
struct HistoryStoreTests {
    @Test("Message commit is atomic and duplicate safe")
    func commitIsDuplicateSafe() async throws {
        let store = try HistoryStore(inMemory: true)
        let publication = MQTTMessage(
            topic: Self.temperatureTopic,
            payload: try Self.fixture(named: "temperature"),
            qualityOfService: 1,
            isRetained: true,
            isDuplicate: false
        )
        let decoder = CanonicalMessageDecoder()
        let topic = try CanonicalTopic(parsing: publication.topic)
        let message = try decoder.decode(publication.payload, for: topic)

        #expect(
            try await store.ingest(
                message,
                publication: publication,
                receivedAt: Date(timeIntervalSince1970: 200)
            )
        )
        #expect(
            try await store.ingest(
                message,
                publication: publication,
                receivedAt: Date(timeIntervalSince1970: 201)
            ) == false
        )

        let status = try await store.status()
        let states = try await store.latestStates()
        #expect(status.messageCount == 1)
        #expect(states.count == 1)
        #expect(states.first?.messageID == message.messageID.rawValue)
    }

    @Test("Older state never replaces a newer projection")
    func olderStateDoesNotReplaceNewerState() async throws {
        let store = try HistoryStore(inMemory: true)
        let newerPublication = MQTTMessage(
            topic: Self.temperatureTopic,
            payload: try Self.fixture(named: "temperature"),
            qualityOfService: 1,
            isRetained: true,
            isDuplicate: false
        )
        let decoder = CanonicalMessageDecoder()
        let topic = try CanonicalTopic(parsing: Self.temperatureTopic)
        let newer = try decoder.decode(newerPublication.payload, for: topic)

        _ = try await store.ingest(
            newer,
            publication: newerPublication,
            receivedAt: Date()
        )

        let older = CanonicalMessage(
            schema: newer.schema,
            messageID: try #require(.init(rawValue: "older-message")),
            source: newer.source,
            observedAt: Date(timeIntervalSince1970: 1),
            publishedAt: Date(timeIntervalSince1970: 1),
            sequence: newer.sequence,
            quality: newer.quality,
            correlationID: nil,
            causationID: nil,
            body: newer.body
        )
        let olderPublication = MQTTMessage(
            topic: Self.temperatureTopic,
            payload: Data("older".utf8),
            qualityOfService: 1,
            isRetained: true,
            isDuplicate: false
        )
        _ = try await store.ingest(
            older,
            publication: olderPublication,
            receivedAt: Date()
        )

        let state = try #require(try await store.latestStates().first)
        #expect(state.messageID == newer.messageID.rawValue)
    }

    @Test("Duplicate detection survives reopening the database")
    func duplicateDetectionSurvivesRestart() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "dwell-history-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let databaseURL = directory.appending(path: "history.sqlite")
        let publication = MQTTMessage(
            topic: Self.temperatureTopic,
            payload: try Self.fixture(named: "temperature"),
            qualityOfService: 1,
            isRetained: true,
            isDuplicate: false
        )
        let decoder = CanonicalMessageDecoder()
        let topic = try CanonicalTopic(parsing: publication.topic)
        let message = try decoder.decode(publication.payload, for: topic)

        do {
            let firstStore = try HistoryStore(at: databaseURL)
            #expect(
                try await firstStore.ingest(
                    message,
                    publication: publication,
                    receivedAt: Date()
                )
            )
        }

        let reopenedStore = try HistoryStore(at: databaseURL)
        #expect(
            try await reopenedStore.ingest(
                message,
                publication: publication,
                receivedAt: Date()
            ) == false
        )
        #expect(try await reopenedStore.status().messageCount == 1)
    }

    @Test("Command lifecycle moves from pending to applied")
    func commandLifecycleIsProjected() async throws {
        let store = try HistoryStore(inMemory: true)
        let command = try publication(
            topic: "dwell/v1/i/home-a/device/light/component/main/command/light.level",
            fixture: "light-command",
            now: .distantPast
        )
        _ = try await store.ingest(
            command.message,
            publication: command.publication,
            receivedAt: Date(timeIntervalSince1970: 100)
        )
        #expect(
            try await store.commandSnapshots(
                now: Date(timeIntervalSince1970: 101)
            ).first?.status == .pending
        )

        let acknowledgement = try publication(
            topic: "dwell/v1/i/home-a/device/light/component/main/ack/light.level",
            fixture: "light-acknowledgement"
        )
        _ = try await store.ingest(
            acknowledgement.message,
            publication: acknowledgement.publication,
            receivedAt: Date(timeIntervalSince1970: 102)
        )
        let snapshot = try #require(
            try await store.commandSnapshots(
                now: Date(timeIntervalSince1970: 103)
            ).first
        )
        #expect(snapshot.commandID == "cmd-001")
        #expect(snapshot.status == .applied)
    }

    @Test("Unacknowledged commands time out")
    func commandTimeoutIsDerived() async throws {
        let store = try HistoryStore(inMemory: true)
        let command = try publication(
            topic: "dwell/v1/i/home-a/device/light/component/main/command/light.level",
            fixture: "light-command",
            now: .distantPast
        )
        _ = try await store.ingest(
            command.message,
            publication: command.publication,
            receivedAt: Date(timeIntervalSince1970: 100)
        )

        #expect(
            try await store.commandSnapshots(now: .distantFuture)
                .first?.status == .timedOut
        )
    }

    private static let temperatureTopic =
        "dwell/v1/i/home-a/device/sensor/component/main/state/sensor.temperature"

    private static func fixture(named name: String) throws -> Data {
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

    private func publication(
        topic: String,
        fixture: String,
        now: Date = Date()
    ) throws -> (message: CanonicalMessage, publication: MQTTMessage) {
        let payload = try Self.fixture(named: fixture)
        let publication = MQTTMessage(
            topic: topic,
            payload: payload,
            qualityOfService: 1,
            isRetained: false,
            isDuplicate: false
        )
        return (
            try CanonicalMessageDecoder().decode(
                payload,
                for: CanonicalTopic(parsing: topic),
                now: now
            ),
            publication
        )
    }
}
