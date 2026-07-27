// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// A client capable of reading the local Dwell authority.
public protocol DwellServiceClient: Sendable {
    /// Returns the daemon's current health snapshot.
    func healthSnapshot() async throws -> HealthSnapshot
}

/// A service client backed by an injected operation.
public struct InProcessDwellServiceClient: DwellServiceClient {
    private let operation: @Sendable () async throws -> HealthSnapshot

    /// Creates an in-process client.
    ///
    /// - Parameter operation: The operation that produces a health snapshot.
    public init(
        operation: @escaping @Sendable () async throws -> HealthSnapshot
    ) {
        self.operation = operation
    }

    /// Returns the injected service's current health snapshot.
    public func healthSnapshot() async throws -> HealthSnapshot {
        try await operation()
    }
}
