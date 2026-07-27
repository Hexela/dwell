// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain

/// A client capable of reading the local Dwell authority.
public protocol DwellServiceClient: Sendable {
    /// Returns the daemon's current health snapshot.
    func healthSnapshot() async throws -> HealthSnapshot

    /// Returns the daemon's current device registry snapshot.
    func deviceSnapshot() async throws -> DeviceCollectionSnapshot

    /// Requests an ordinary device effect through the daemon.
    func perform(
        _ command: DeviceCommandRequest
    ) async throws -> DeviceCommandAcceptance
}

/// A service client backed by an injected operation.
public struct InProcessDwellServiceClient: DwellServiceClient {
    private let operation: @Sendable () async throws -> HealthSnapshot
    private let deviceOperation: @Sendable () async throws -> DeviceCollectionSnapshot

    /// Creates an in-process client.
    ///
    /// - Parameter operation: The operation that produces a health snapshot.
    public init(
        operation: @escaping @Sendable () async throws -> HealthSnapshot,
        deviceOperation: @escaping @Sendable () async throws -> DeviceCollectionSnapshot = {
            DeviceCollectionSnapshot(revision: 0, devices: [])
        }
    ) {
        self.operation = operation
        self.deviceOperation = deviceOperation
    }

    /// Returns the injected service's current health snapshot.
    public func healthSnapshot() async throws -> HealthSnapshot {
        try await operation()
    }

    public func deviceSnapshot() async throws -> DeviceCollectionSnapshot {
        try await deviceOperation()
    }

    public func perform(
        _ command: DeviceCommandRequest
    ) async throws -> DeviceCommandAcceptance {
        throw ServiceRequestError.serviceUnavailable
    }
}
