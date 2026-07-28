// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation
import DwellDomain

/// A durable latest-state projection suitable for startup reconciliation.
public struct PersistedState: Equatable, Sendable {
    public let topic: String
    public let messageID: String
    public let sourceTimestamp: Date
    public let receivedAt: Date
    public let payload: Data

    public init(
        topic: String,
        messageID: String,
        sourceTimestamp: Date,
        receivedAt: Date,
        payload: Data
    ) {
        self.topic = topic
        self.messageID = messageID
        self.sourceTimestamp = sourceTimestamp
        self.receivedAt = receivedAt
        self.payload = payload
    }
}

/// Summary of the operational store used by health reporting.
public struct HistoryStoreStatus: Equatable, Sendable {
    public let schemaVersion: Int
    public let messageCount: Int
    public let latestCommitAt: Date?

    public init(
        schemaVersion: Int,
        messageCount: Int,
        latestCommitAt: Date?
    ) {
        self.schemaVersion = schemaVersion
        self.messageCount = messageCount
        self.latestCommitAt = latestCommitAt
    }
}

/// A durable command lifecycle record suitable for client presentation.
public struct PersistedCommand: Equatable, Sendable {
    public let commandID: String
    public let deviceID: DwellIdentifier
    public let componentID: DwellIdentifier
    public let capability: String
    public let status: DeviceCommandSnapshot.Status
    public let requestedAt: Date
    public let expiresAt: Date
    public let completedAt: Date?
}
