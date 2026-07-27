// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import Foundation

/// A canonical quantity reading with an explicit unit.
public struct QuantityState: Codable, Equatable, Sendable {
    public let value: Double
    public let unit: String

    /// Creates a quantity reading.
    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}

/// A canonical Boolean state.
public struct BooleanState: Codable, Equatable, Sendable {
    public let value: Bool
    public let validForSeconds: Double?

    /// Creates a Boolean state.
    public init(value: Bool, validForSeconds: Double? = nil) {
        self.value = value
        self.validForSeconds = validForSeconds
    }
}

/// A closed numeric range used by a level state.
public struct LevelRange: Codable, Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double

    /// Creates a closed level range.
    public init(minimum: Double, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// A canonical numeric level and its supported range.
public struct LevelState: Codable, Equatable, Sendable {
    public let value: Double
    public let range: LevelRange

    /// Creates a level state.
    public init(value: Double, range: LevelRange) {
        self.value = value
        self.range = range
    }
}

/// A canonical string state constrained to a declared set of values.
public struct EnumerationState: Codable, Equatable, Sendable {
    public let value: String
    public let allowed: [String]

    /// Creates an enumeration state.
    public init(value: String, allowed: [String]) {
        self.value = value
        self.allowed = allowed
    }
}

/// A device or integration availability state.
public struct AvailabilityState: Codable, Equatable, Sendable {
    /// A canonical availability classification.
    public enum Status: String, Codable, Sendable {
        case online
        case degraded
        case offline
        case unknown
    }

    public let status: Status
    public let since: Date?
    public let reason: String?

    /// Creates an availability state.
    public init(status: Status, since: Date? = nil, reason: String? = nil) {
        self.status = status
        self.since = since
        self.reason = reason
    }
}

/// The user or subsystem origin of a canonical command.
public struct CommandOrigin: Codable, Equatable, Sendable {
    /// A recognized command origin.
    public enum Kind: String, Codable, Sendable {
        case automation
        case scene
        case user
        case interface
        case federation
        case system
    }

    public let kind: Kind
    public let id: String?
    public let installationID: DwellIdentifier?

    /// Creates a command origin.
    public init(
        kind: Kind,
        id: String? = nil,
        installationID: DwellIdentifier? = nil
    ) {
        self.kind = kind
        self.id = id
        self.installationID = installationID
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case installationID = "installationId"
    }
}

/// An optional optimistic-concurrency condition on a command.
public struct CommandPrecondition: Codable, Equatable, Sendable {
    public let revision: UInt64

    /// Creates a revision precondition.
    public init(revision: UInt64) {
        self.revision = revision
    }
}

/// A canonical request for a device or scene effect.
public struct Command: Codable, Equatable, Sendable {
    /// The policy risk associated with the requested effect.
    public enum Risk: String, Codable, Sendable {
        case ordinary
        case privacySensitive = "privacy-sensitive"
        case securitySensitive = "security-sensitive"
        case safetyCritical = "safety-critical"
    }

    public let commandID: MessageID
    public let operation: String
    public let value: JSONValue
    public let expiresAt: Date
    public let expected: CommandPrecondition?
    public let origin: CommandOrigin
    public let risk: Risk

    /// Creates a canonical command.
    public init(
        commandID: MessageID,
        operation: String,
        value: JSONValue,
        expiresAt: Date,
        expected: CommandPrecondition? = nil,
        origin: CommandOrigin,
        risk: Risk
    ) {
        self.commandID = commandID
        self.operation = operation
        self.value = value
        self.expiresAt = expiresAt
        self.expected = expected
        self.origin = origin
        self.risk = risk
    }

    private enum CodingKeys: String, CodingKey {
        case commandID = "commandId"
        case operation
        case value
        case expiresAt
        case expected
        case origin
        case risk
    }
}

/// The result of processing a canonical command.
public struct CommandAcknowledgement: Codable, Equatable, Sendable {
    /// A canonical command outcome.
    public enum Status: String, Codable, Sendable {
        case accepted
        case applied
        case rejected
        case failed
        case expired
        case unknownOutcome = "unknown-outcome"
    }

    public let commandID: MessageID
    public let status: Status
    public let resultingState: JSONValue?
    public let error: JSONValue?

    /// Creates a command acknowledgement.
    public init(
        commandID: MessageID,
        status: Status,
        resultingState: JSONValue? = nil,
        error: JSONValue? = nil
    ) {
        self.commandID = commandID
        self.status = status
        self.resultingState = resultingState
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case commandID = "commandId"
        case status
        case resultingState
        case error
    }
}

/// A supported, validated canonical payload body.
public enum CanonicalBody: Equatable, Sendable {
    case quantity(QuantityState)
    case boolean(BooleanState)
    case level(LevelState)
    case enumeration(EnumerationState)
    case availability(AvailabilityState)
    case command(Command)
    case acknowledgement(CommandAcknowledgement)
}
