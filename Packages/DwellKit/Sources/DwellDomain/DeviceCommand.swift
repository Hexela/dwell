// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// An ordinary device effect requested by a signed local client.
public struct DeviceCommandRequest: Codable, Equatable, Sendable {
    public let deviceID: DwellIdentifier
    public let componentID: DwellIdentifier
    public let capability: String
    public let value: CapabilitySnapshot.Value
    public let idempotencyKey: UUID

    public init(
        deviceID: DwellIdentifier,
        componentID: DwellIdentifier,
        capability: String,
        value: CapabilitySnapshot.Value,
        idempotencyKey: UUID
    ) {
        self.deviceID = deviceID
        self.componentID = componentID
        self.capability = capability
        self.value = value
        self.idempotencyKey = idempotencyKey
    }
}

/// The daemon's durable acceptance state for a device command.
public struct DeviceCommandAcceptance: Codable, Equatable, Sendable {
    public let commandID: String
    public let wasPublished: Bool

    public init(commandID: String, wasPublished: Bool) {
        self.commandID = commandID
        self.wasPublished = wasPublished
    }
}
