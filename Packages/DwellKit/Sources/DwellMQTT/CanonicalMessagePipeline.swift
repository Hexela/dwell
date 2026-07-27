// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellSchemas
import Foundation

/// The result of validating and deduplicating an inbound publication.
public enum InboundMessageResult: Sendable {
    case accepted(CanonicalMessage)
    case duplicate
    case rejected(code: String)
}

/// Validates canonical topics and payloads with bounded message-ID deduplication.
public actor CanonicalMessagePipeline {
    private let decoder: CanonicalMessageDecoder
    private let deduplicationCapacity: Int
    private let durableIngester: (any CanonicalMessageIngesting)?
    private var messageIdentifiers: Set<MessageID> = []
    private var insertionOrder: [MessageID] = []

    /// Creates an inbound canonical-message pipeline.
    public init(
        maximumPayloadSize: Int = CanonicalMessageDecoder.defaultMaximumPayloadSize,
        deduplicationCapacity: Int = 4_096,
        durableIngester: (any CanonicalMessageIngesting)? = nil
    ) {
        precondition(deduplicationCapacity > 0)
        decoder = CanonicalMessageDecoder(maximumPayloadSize: maximumPayloadSize)
        self.deduplicationCapacity = deduplicationCapacity
        self.durableIngester = durableIngester
    }

    /// Validates one transport publication.
    public func process(
        _ publication: MQTTMessage,
        now: Date = Date()
    ) async -> InboundMessageResult {
        let topic: CanonicalTopic
        do {
            topic = try CanonicalTopic(parsing: publication.topic)
        } catch {
            return .rejected(code: "invalid-topic")
        }

        let message: CanonicalMessage
        do {
            message = try decoder.decode(publication.payload, for: topic, now: now)
        } catch let error as CanonicalMessageValidationError {
            return .rejected(code: error.code)
        } catch {
            return .rejected(code: "invalid-message")
        }

        guard messageIdentifiers.contains(message.messageID) == false else {
            return .duplicate
        }

        if let durableIngester {
            do {
                guard try await durableIngester.ingest(
                    message,
                    publication: publication,
                    receivedAt: now
                ) else {
                    return .duplicate
                }
            } catch {
                return .rejected(code: CanonicalMessageIngestionError.unavailable.rawValue)
            }
        }

        guard messageIdentifiers.insert(message.messageID).inserted else {
            return .duplicate
        }
        insertionOrder.append(message.messageID)
        if insertionOrder.count > deduplicationCapacity {
            messageIdentifiers.remove(insertionOrder.removeFirst())
        }
        return .accepted(message)
    }
}
