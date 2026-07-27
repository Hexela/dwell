// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellHistory
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
}
