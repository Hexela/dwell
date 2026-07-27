// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// The current broker-session lifecycle.
public enum BrokerConnectionState: String, Codable, Sendable {
    case disabled
    case connecting
    case online
    case reconnecting
    case stopped
}

/// A redacted broker diagnostic snapshot.
public struct BrokerStatus: Equatable, Sendable {
    public let state: BrokerConnectionState
    public let reconnectCount: UInt
    public let acceptedMessageCount: UInt
    public let duplicateMessageCount: UInt
    public let rejectedMessageCount: UInt
    public let lastMessageAt: Date?
    public let lastErrorCode: String?

    /// Creates a broker diagnostic snapshot.
    public init(
        state: BrokerConnectionState,
        reconnectCount: UInt = 0,
        acceptedMessageCount: UInt = 0,
        duplicateMessageCount: UInt = 0,
        rejectedMessageCount: UInt = 0,
        lastMessageAt: Date? = nil,
        lastErrorCode: String? = nil
    ) {
        self.state = state
        self.reconnectCount = reconnectCount
        self.acceptedMessageCount = acceptedMessageCount
        self.duplicateMessageCount = duplicateMessageCount
        self.rejectedMessageCount = rejectedMessageCount
        self.lastMessageAt = lastMessageAt
        self.lastErrorCode = lastErrorCode
    }
}
