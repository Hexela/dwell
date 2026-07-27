// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import Foundation

/// A local client role declared during service negotiation.
public enum ClientRole: String, Codable, Sendable {
    case application
    case commandLineTool = "command-line-tool"
    case agent
    case widget
}

/// A request for the daemon's current health snapshot.
public struct HealthSnapshotRequest: Codable, Equatable, Sendable {
    public let protocolVersion: ServiceProtocolVersion
    public let role: ClientRole

    /// Creates a health snapshot request.
    public init(protocolVersion: ServiceProtocolVersion, role: ClientRole) {
        self.protocolVersion = protocolVersion
        self.role = role
    }
}

/// A wire response containing either a snapshot or a stable service error.
public struct HealthSnapshotResponse: Codable, Equatable, Sendable {
    public let snapshot: HealthSnapshot?
    public let error: ServiceRequestError?

    /// Creates a successful response.
    public static func success(_ snapshot: HealthSnapshot) -> Self {
        Self(snapshot: snapshot, error: nil)
    }

    /// Creates a rejected response.
    public static func failure(_ error: ServiceRequestError) -> Self {
        Self(snapshot: nil, error: error)
    }

    private init(snapshot: HealthSnapshot?, error: ServiceRequestError?) {
        self.snapshot = snapshot
        self.error = error
    }
}

/// A request for the daemon's current device registry.
public struct DeviceSnapshotRequest: Codable, Equatable, Sendable {
    public let protocolVersion: ServiceProtocolVersion
    public let role: ClientRole

    public init(protocolVersion: ServiceProtocolVersion, role: ClientRole) {
        self.protocolVersion = protocolVersion
        self.role = role
    }
}

/// A wire response containing a device collection or stable error.
public struct DeviceSnapshotResponse: Codable, Equatable, Sendable {
    public let snapshot: DeviceCollectionSnapshot?
    public let error: ServiceRequestError?

    public static func success(_ snapshot: DeviceCollectionSnapshot) -> Self {
        Self(snapshot: snapshot, error: nil)
    }

    public static func failure(_ error: ServiceRequestError) -> Self {
        Self(snapshot: nil, error: error)
    }

    private init(
        snapshot: DeviceCollectionSnapshot?,
        error: ServiceRequestError?
    ) {
        self.snapshot = snapshot
        self.error = error
    }
}

public struct DeviceCommandWireRequest: Codable, Equatable, Sendable {
    public let protocolVersion: ServiceProtocolVersion
    public let role: ClientRole
    public let command: DeviceCommandRequest

    public init(
        protocolVersion: ServiceProtocolVersion,
        role: ClientRole,
        command: DeviceCommandRequest
    ) {
        self.protocolVersion = protocolVersion
        self.role = role
        self.command = command
    }
}

public struct DeviceCommandWireResponse: Codable, Equatable, Sendable {
    public let acceptance: DeviceCommandAcceptance?
    public let error: ServiceRequestError?

    public static func success(_ acceptance: DeviceCommandAcceptance) -> Self {
        Self(acceptance: acceptance, error: nil)
    }

    public static func failure(_ error: ServiceRequestError) -> Self {
        Self(acceptance: nil, error: error)
    }
}

/// A stable failure returned by the local service boundary.
public enum ServiceRequestError: String, Codable, Error, Sendable {
    case incompatibleProtocol = "incompatible-protocol"
    case unauthorizedClient = "unauthorized-client"
    case malformedRequest = "malformed-request"
    case malformedResponse = "malformed-response"
    case serviceUnavailable = "service-unavailable"
}

/// The Objective-C-compatible XPC wire surface.
@objc public protocol DwellXPCWireService {
    /// Returns an encoded `HealthSnapshotResponse`.
    func healthSnapshot(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    )

    /// Returns an encoded `DeviceSnapshotResponse`.
    func deviceSnapshot(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    )

    func performDeviceCommand(
        _ request: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    )
}
