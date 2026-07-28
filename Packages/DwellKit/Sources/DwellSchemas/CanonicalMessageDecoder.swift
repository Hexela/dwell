// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import Foundation

/// Decodes and validates canonical MQTT payloads.
public struct CanonicalMessageDecoder: Sendable {
    /// The default accepted payload size of 64 KiB.
    public static let defaultMaximumPayloadSize = 64 * 1_024

    /// The protocol's absolute payload limit of 256 KiB.
    public static let absoluteMaximumPayloadSize = 256 * 1_024

    public let maximumPayloadSize: Int

    /// Creates a decoder with a bounded payload limit.
    ///
    /// - Parameter maximumPayloadSize: The largest accepted payload in bytes.
    ///   The value must be between 1 and 256 KiB.
    public init(maximumPayloadSize: Int = Self.defaultMaximumPayloadSize) {
        precondition(
            (1...Self.absoluteMaximumPayloadSize).contains(maximumPayloadSize),
            "Canonical payload limit must be between 1 and 256 KiB."
        )
        self.maximumPayloadSize = maximumPayloadSize
    }

    /// Decodes and validates a payload for its canonical topic.
    ///
    /// - Parameters:
    ///   - payload: The UTF-8 JSON payload bytes.
    ///   - topic: The already validated canonical MQTT topic.
    ///   - now: The wall-clock time used to reject expired commands.
    /// - Returns: A typed message safe to pass into Dwell Core.
    /// - Throws: ``CanonicalMessageValidationError`` with a stable diagnostic
    ///   code when validation fails.
    public func decode(
        _ payload: Data,
        for topic: CanonicalTopic,
        now: Date = Date()
    ) throws -> CanonicalMessage {
        guard payload.count <= maximumPayloadSize else {
            throw CanonicalMessageValidationError.payloadTooLarge(
                maximumBytes: maximumPayloadSize
            )
        }

        let envelope: WireEnvelope
        do {
            envelope = try Self.makeJSONDecoder().decode(WireEnvelope.self, from: payload)
        } catch {
            throw CanonicalMessageValidationError.invalidEnvelope
        }

        guard envelope.source.installationID == topic.installation else {
            throw CanonicalMessageValidationError.installationMismatch
        }

        guard envelope.quality.confidence.map({ (0...1).contains($0) }) ?? true else {
            throw CanonicalMessageValidationError.invalidBody(
                reason: "quality-confidence-out-of-range"
            )
        }

        guard let schema = CanonicalSchema(identifier: envelope.schema) else {
            throw CanonicalMessageValidationError.unsupportedSchema(
                envelope.schema.rawValue
            )
        }

        guard Self.route(topic.route, accepts: schema) else {
            throw CanonicalMessageValidationError.topicSchemaMismatch
        }

        let body = try decodeBody(
            envelope.body,
            schema: schema,
            envelope: envelope,
            now: now
        )

        return CanonicalMessage(
            schema: envelope.schema,
            messageID: envelope.messageID,
            source: envelope.source,
            observedAt: envelope.observedAt,
            publishedAt: envelope.publishedAt,
            sequence: envelope.sequence,
            quality: envelope.quality,
            correlationID: envelope.correlationID,
            causationID: envelope.causationID,
            body: body
        )
    }

    private func decodeBody(
        _ value: JSONValue,
        schema: CanonicalSchema,
        envelope: WireEnvelope,
        now: Date
    ) throws -> CanonicalBody {
        do {
            switch schema {
            case .deviceMetadata:
                let body: DeviceComponentMetadata = try Self.decode(value)
                guard body.deviceName.isEmpty == false,
                      body.componentName.isEmpty == false,
                      body.capabilities.allSatisfy(Self.validMetadataCapability)
                else {
                    throw BodyValidationError.invalid
                }
                return .deviceMetadata(body)

            case .quantityState:
                let body: QuantityState = try Self.decode(value)
                guard body.value.isFinite, body.unit.isEmpty == false else {
                    throw BodyValidationError.invalid
                }
                return .quantity(body)

            case .booleanState:
                let body: BooleanState = try Self.decode(value)
                guard body.validForSeconds.map({ $0.isFinite && $0 > 0 }) ?? true else {
                    throw BodyValidationError.invalid
                }
                return .boolean(body)

            case .levelState:
                let body: LevelState = try Self.decode(value)
                guard body.value.isFinite,
                      body.range.minimum.isFinite,
                      body.range.maximum.isFinite,
                      body.range.minimum <= body.range.maximum,
                      (body.range.minimum...body.range.maximum).contains(body.value)
                else {
                    throw BodyValidationError.invalid
                }
                return .level(body)

            case .enumerationState:
                let body: EnumerationState = try Self.decode(value)
                guard body.allowed.isEmpty == false,
                      Set(body.allowed).count == body.allowed.count,
                      body.allowed.contains(body.value)
                else {
                    throw BodyValidationError.invalid
                }
                return .enumeration(body)

            case .availability:
                return .availability(try Self.decode(value))

            case .command:
                let body: Command = try Self.decode(value)
                guard body.operation.isEmpty == false,
                      body.commandID == envelope.messageID,
                      body.expiresAt > envelope.publishedAt
                else {
                    throw BodyValidationError.invalid
                }
                guard body.expiresAt > now else {
                    throw CanonicalMessageValidationError.expiredCommand
                }
                return .command(body)

            case .commandAcknowledgement:
                let body: CommandAcknowledgement = try Self.decode(value)
                guard envelope.causationID == body.commandID else {
                    throw BodyValidationError.invalid
                }
                return .acknowledgement(body)
            }
        } catch let error as CanonicalMessageValidationError {
            throw error
        } catch {
            throw CanonicalMessageValidationError.invalidBody(
                reason: "schema-constraint-failed"
            )
        }
    }

    private static func decode<Value: Decodable>(_ value: JSONValue) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try makeJSONDecoder().decode(Value.self, from: data)
    }

    private static func validMetadataCapability(
        _ capability: CapabilityMetadata
    ) -> Bool {
        guard CapabilityName(rawValue: capability.capability) != nil,
              capability.displayName.isEmpty == false,
              capability.minimum?.isFinite ?? true,
              capability.maximum?.isFinite ?? true
        else {
            return false
        }
        if let minimum = capability.minimum,
           let maximum = capability.maximum
        {
            return minimum <= maximum
        }
        return true
    }

    private static func route(
        _ route: CanonicalTopic.Route,
        accepts schema: CanonicalSchema
    ) -> Bool {
        switch (route, schema) {
        case (.deviceMetadata, .deviceMetadata),
             (.deviceState, .quantityState),
             (.deviceState, .booleanState),
             (.deviceState, .levelState),
             (.deviceState, .enumerationState),
             (.deviceAvailability, .availability),
             (.deviceCommand, .command),
             (.sceneCommand, .command),
             (.deviceAcknowledgement, .commandAcknowledgement):
            true
        default:
            false
        }
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = StrictTimestamp.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an RFC 3339 UTC timestamp with fractional seconds."
                )
            }
            return date
        }
        return decoder
    }
}

/// A stable validation failure suitable for diagnostics and traces.
public enum CanonicalMessageValidationError: Error, Equatable, Sendable {
    case payloadTooLarge(maximumBytes: Int)
    case invalidEnvelope
    case unsupportedSchema(String)
    case installationMismatch
    case topicSchemaMismatch
    case invalidBody(reason: String)
    case expiredCommand

    /// The stable machine-readable reason code.
    public var code: String {
        switch self {
        case .payloadTooLarge:
            "payload-too-large"
        case .invalidEnvelope:
            "invalid-envelope"
        case .unsupportedSchema:
            "unsupported-schema"
        case .installationMismatch:
            "installation-mismatch"
        case .topicSchemaMismatch:
            "topic-schema-mismatch"
        case .invalidBody:
            "invalid-body"
        case .expiredCommand:
            "expired-command"
        }
    }
}

private struct WireEnvelope: Decodable {
    let schema: SchemaID
    let messageID: MessageID
    let source: MessageSource
    let observedAt: Date?
    let publishedAt: Date
    let sequence: UInt64?
    let quality: MessageQuality
    let correlationID: CorrelationID?
    let causationID: MessageID?
    let body: JSONValue

    private enum CodingKeys: String, CodingKey {
        case schema
        case messageID = "messageId"
        case source
        case observedAt
        case publishedAt
        case sequence
        case quality
        case correlationID = "correlationId"
        case causationID = "causationId"
        case body
    }
}

private enum BodyValidationError: Error {
    case invalid
}

private enum StrictTimestamp {
    static func date(from value: String) -> Date? {
        guard value.hasSuffix("Z"),
              let separator = value.lastIndex(of: "."),
              separator < value.index(before: value.endIndex)
        else {
            return nil
        }

        let fractionalStart = value.index(after: separator)
        let fractionalEnd = value.index(before: value.endIndex)
        let fractional = value[fractionalStart..<fractionalEnd]
        guard (1...9).contains(fractional.count),
              fractional.allSatisfy(\.isNumber)
        else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }
}
