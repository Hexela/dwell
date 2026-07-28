// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// A current, typed capability value exposed to Dwell clients.
public struct CapabilitySnapshot: Codable, Equatable, Identifiable, Sendable {
    public enum Value: Codable, Equatable, Sendable {
        case number(Double, unit: String?)
        case boolean(Bool)
        case text(String)
    }

    public var id: String { "\(componentID.rawValue)/\(capability)" }
    public let componentID: DwellIdentifier
    public let capability: String
    public let value: Value
    public let observedAt: Date
    public let revision: UInt64
    public let isStale: Bool
    public let displayName: String
    public let isWritable: Bool
    public let minimum: Double?
    public let maximum: Double?

    public init(
        componentID: DwellIdentifier,
        capability: String,
        value: Value,
        observedAt: Date,
        revision: UInt64,
        isStale: Bool,
        displayName: String? = nil,
        isWritable: Bool = false,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) {
        self.componentID = componentID
        self.capability = capability
        self.value = value
        self.observedAt = observedAt
        self.revision = revision
        self.isStale = isStale
        self.displayName = displayName ?? capability
        self.isWritable = isWritable
        self.minimum = minimum
        self.maximum = maximum
    }

    private enum CodingKeys: String, CodingKey {
        case componentID
        case capability
        case value
        case observedAt
        case revision
        case isStale
        case displayName
        case isWritable
        case minimum
        case maximum
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        componentID = try container.decode(
            DwellIdentifier.self,
            forKey: .componentID
        )
        capability = try container.decode(String.self, forKey: .capability)
        value = try container.decode(Value.self, forKey: .value)
        observedAt = try container.decode(Date.self, forKey: .observedAt)
        revision = try container.decode(UInt64.self, forKey: .revision)
        isStale = try container.decode(Bool.self, forKey: .isStale)
        displayName = try container.decodeIfPresent(
            String.self,
            forKey: .displayName
        ) ?? capability
        isWritable = try container.decodeIfPresent(
            Bool.self,
            forKey: .isWritable
        ) ?? false
        minimum = try container.decodeIfPresent(
            Double.self,
            forKey: .minimum
        )
        maximum = try container.decodeIfPresent(
            Double.self,
            forKey: .maximum
        )
    }
}

/// The durable lifecycle of a command exposed to local clients.
public struct DeviceCommandSnapshot: Codable, Equatable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case pending
        case applied
        case rejected
        case failed
        case expired
        case timedOut = "timed-out"
        case unknownOutcome = "unknown-outcome"
    }

    public var id: String { commandID }
    public let commandID: String
    public let deviceID: DwellIdentifier
    public let componentID: DwellIdentifier
    public let capability: String
    public let status: Status
    public let requestedAt: Date
    public let completedAt: Date?

    public init(
        commandID: String,
        deviceID: DwellIdentifier,
        componentID: DwellIdentifier,
        capability: String,
        status: Status,
        requestedAt: Date,
        completedAt: Date? = nil
    ) {
        self.commandID = commandID
        self.deviceID = deviceID
        self.componentID = componentID
        self.capability = capability
        self.status = status
        self.requestedAt = requestedAt
        self.completedAt = completedAt
    }
}

/// An immutable client view of one canonical device.
public struct DeviceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: DwellIdentifier { deviceID }
    public let deviceID: DwellIdentifier
    public let displayName: String
    public let availability: String
    public let capabilities: [CapabilitySnapshot]
    public let manufacturer: String?
    public let model: String?
    public let commands: [DeviceCommandSnapshot]
    public let revision: UInt64

    public init(
        deviceID: DwellIdentifier,
        displayName: String,
        availability: String,
        capabilities: [CapabilitySnapshot],
        manufacturer: String? = nil,
        model: String? = nil,
        commands: [DeviceCommandSnapshot] = [],
        revision: UInt64
    ) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.availability = availability
        self.capabilities = capabilities
        self.manufacturer = manufacturer
        self.model = model
        self.commands = commands
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case deviceID
        case displayName
        case availability
        case capabilities
        case manufacturer
        case model
        case commands
        case revision
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(
            DwellIdentifier.self,
            forKey: .deviceID
        )
        displayName = try container.decode(String.self, forKey: .displayName)
        availability = try container.decode(
            String.self,
            forKey: .availability
        )
        capabilities = try container.decode(
            [CapabilitySnapshot].self,
            forKey: .capabilities
        )
        manufacturer = try container.decodeIfPresent(
            String.self,
            forKey: .manufacturer
        )
        model = try container.decodeIfPresent(String.self, forKey: .model)
        commands = try container.decodeIfPresent(
            [DeviceCommandSnapshot].self,
            forKey: .commands
        ) ?? []
        revision = try container.decode(UInt64.self, forKey: .revision)
    }
}

/// A consistent collection of device snapshots.
public struct DeviceCollectionSnapshot: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let devices: [DeviceSnapshot]

    public init(revision: UInt64, devices: [DeviceSnapshot]) {
        self.revision = revision
        self.devices = devices
    }
}
