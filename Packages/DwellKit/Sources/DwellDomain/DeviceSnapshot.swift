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

    public init(
        componentID: DwellIdentifier,
        capability: String,
        value: Value,
        observedAt: Date,
        revision: UInt64,
        isStale: Bool
    ) {
        self.componentID = componentID
        self.capability = capability
        self.value = value
        self.observedAt = observedAt
        self.revision = revision
        self.isStale = isStale
    }
}

/// An immutable client view of one canonical device.
public struct DeviceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: DwellIdentifier { deviceID }
    public let deviceID: DwellIdentifier
    public let displayName: String
    public let availability: String
    public let capabilities: [CapabilitySnapshot]
    public let revision: UInt64

    public init(
        deviceID: DwellIdentifier,
        displayName: String,
        availability: String,
        capabilities: [CapabilitySnapshot],
        revision: UInt64
    ) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.availability = availability
        self.capabilities = capabilities
        self.revision = revision
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
