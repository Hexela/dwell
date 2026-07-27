// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellMQTT
import DwellSchemas
import Foundation
import GRDB

/// Owns the append-heavy operational database and its state projection.
public final class HistoryStore: CanonicalMessageIngesting, Sendable {
    private let database: any DatabaseWriter

    /// Opens or creates an operational store and applies forward migrations.
    public init(at url: URL) throws {
        var configuration = Configuration()
        configuration.busyMode = .timeout(5)
        configuration.prepareDatabase { database in
            try database.execute(sql: "PRAGMA foreign_keys = ON")
        }
        database = try DatabasePool(path: url.path, configuration: configuration)
        try Self.migrator.migrate(database)
    }

    /// Creates an isolated in-memory store for tests.
    public init(inMemory: Bool) throws {
        precondition(inMemory)
        var configuration = Configuration()
        configuration.prepareDatabase { database in
            try database.execute(sql: "PRAGMA foreign_keys = ON")
        }
        database = try DatabaseQueue(configuration: configuration)
        try Self.migrator.migrate(database)
    }

    public func ingest(
        _ message: CanonicalMessage,
        publication: MQTTMessage,
        receivedAt: Date
    ) async throws -> Bool {
        try await database.write { database in
            try database.execute(
                sql: """
                    INSERT OR IGNORE INTO inbox
                        (message_id, topic, source_timestamp, received_at, payload)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    message.messageID.rawValue,
                    publication.topic,
                    message.observedAt ?? message.publishedAt,
                    receivedAt,
                    publication.payload,
                ]
            )

            guard database.changesCount == 1 else {
                return false
            }

            try database.execute(
                sql: """
                    INSERT INTO message_history
                        (message_id, topic, source_timestamp, received_at, payload)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    message.messageID.rawValue,
                    publication.topic,
                    message.observedAt ?? message.publishedAt,
                    receivedAt,
                    publication.payload,
                ]
            )

            if Self.projectsLatestState(message) {
                try database.execute(
                    sql: """
                        INSERT INTO latest_state
                            (topic, message_id, source_timestamp, received_at, payload)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(topic) DO UPDATE SET
                            message_id = excluded.message_id,
                            source_timestamp = excluded.source_timestamp,
                            received_at = excluded.received_at,
                            payload = excluded.payload
                        WHERE excluded.source_timestamp >= latest_state.source_timestamp
                        """,
                    arguments: [
                        publication.topic,
                        message.messageID.rawValue,
                        message.observedAt ?? message.publishedAt,
                        receivedAt,
                        publication.payload,
                    ]
                )
            }

            try database.execute(
                sql: """
                    UPDATE store_metadata
                    SET latest_commit_at = ?
                    WHERE singleton = 1
                    """,
                arguments: [receivedAt]
            )
            return true
        }
    }

    /// Returns the state projection restored before broker reconciliation.
    public func latestStates() async throws -> [PersistedState] {
        try await database.read { database in
            let rows = try Row.fetchAll(
                database,
                sql: """
                    SELECT topic, message_id, source_timestamp, received_at, payload
                    FROM latest_state
                    ORDER BY topic
                    """
            )
            return rows.map {
                PersistedState(
                    topic: $0["topic"],
                    messageID: $0["message_id"],
                    sourceTimestamp: $0["source_timestamp"],
                    receivedAt: $0["received_at"],
                    payload: $0["payload"]
                )
            }
        }
    }

    /// Returns a small, redaction-safe health summary.
    public func status() async throws -> HistoryStoreStatus {
        try await database.read { database in
            let messageCount = try Int.fetchOne(
                database,
                sql: "SELECT COUNT(*) FROM inbox"
            ) ?? 0
            let latestCommitAt = try Date.fetchOne(
                database,
                sql: "SELECT latest_commit_at FROM store_metadata WHERE singleton = 1"
            )
            return HistoryStoreStatus(
                schemaVersion: 1,
                messageCount: messageCount,
                latestCommitAt: latestCommitAt
            )
        }
    }

    private static func projectsLatestState(_ message: CanonicalMessage) -> Bool {
        switch message.body {
        case .quantity, .boolean, .level, .enumeration, .availability:
            true
        case .command, .acknowledgement:
            false
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-operational-store") { database in
            try database.create(table: "inbox") { table in
                table.column("message_id", .text).primaryKey()
                table.column("topic", .text).notNull()
                table.column("source_timestamp", .datetime).notNull()
                table.column("received_at", .datetime).notNull()
                table.column("payload", .blob).notNull()
            }
            try database.create(table: "message_history") { table in
                table.autoIncrementedPrimaryKey("sequence")
                table.column("message_id", .text)
                    .notNull()
                    .unique()
                    .references("inbox", onDelete: .cascade)
                table.column("topic", .text).notNull().indexed()
                table.column("source_timestamp", .datetime).notNull().indexed()
                table.column("received_at", .datetime).notNull()
                table.column("payload", .blob).notNull()
            }
            try database.create(table: "latest_state") { table in
                table.column("topic", .text).primaryKey()
                table.column("message_id", .text).notNull()
                table.column("source_timestamp", .datetime).notNull()
                table.column("received_at", .datetime).notNull()
                table.column("payload", .blob).notNull()
            }
            try database.create(table: "store_metadata") { table in
                table.column("singleton", .integer).primaryKey()
                table.column("latest_commit_at", .datetime)
                table.check(sql: "singleton = 1")
            }
            try database.execute(
                sql: "INSERT INTO store_metadata (singleton) VALUES (1)"
            )
        }
        return migrator
    }
}
