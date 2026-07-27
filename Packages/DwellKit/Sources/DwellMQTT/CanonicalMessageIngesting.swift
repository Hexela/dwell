// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellSchemas
import Foundation

/// The durable consumer boundary for validated canonical MQTT messages.
public protocol CanonicalMessageIngesting: Sendable {
    /// Atomically records a message and returns false when its message ID was
    /// already committed.
    func ingest(
        _ message: CanonicalMessage,
        publication: MQTTMessage,
        receivedAt: Date
    ) async throws -> Bool
}

/// Stable failures exposed by the durable ingestion boundary.
public enum CanonicalMessageIngestionError: String, Error, Sendable {
    case unavailable = "persistence-unavailable"
}
