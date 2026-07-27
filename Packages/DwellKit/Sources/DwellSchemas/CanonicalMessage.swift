// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import Foundation

/// A canonical message that has passed envelope, body, and topic validation.
public struct CanonicalMessage: Equatable, Sendable {
    public let schema: SchemaID
    public let messageID: MessageID
    public let source: MessageSource
    public let observedAt: Date?
    public let publishedAt: Date
    public let sequence: UInt64?
    public let quality: MessageQuality
    public let correlationID: CorrelationID?
    public let causationID: MessageID?
    public let body: CanonicalBody

    /// Creates a validated canonical message value.
    public init(
        schema: SchemaID,
        messageID: MessageID,
        source: MessageSource,
        observedAt: Date?,
        publishedAt: Date,
        sequence: UInt64?,
        quality: MessageQuality,
        correlationID: CorrelationID?,
        causationID: MessageID?,
        body: CanonicalBody
    ) {
        self.schema = schema
        self.messageID = messageID
        self.source = source
        self.observedAt = observedAt
        self.publishedAt = publishedAt
        self.sequence = sequence
        self.quality = quality
        self.correlationID = correlationID
        self.causationID = causationID
        self.body = body
    }
}
