// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Builds normalized snapshots from daemon lifecycle and component state.
public struct HealthSnapshotBuilder: Sendable {
    /// Creates a normalized health snapshot.
    public static func makeSnapshot(
        serviceVersion: String,
        requestedLifecycle: ServiceLifecycleState,
        processStartedAt: Date,
        generatedAt: Date,
        uptimeSeconds: Double,
        revision: UInt64,
        components: [ComponentHealth],
        issues: [HealthIssue]
    ) -> HealthSnapshot {
        let lifecycle: ServiceLifecycleState
        if requestedLifecycle == .ready,
           components.contains(where: { $0.state == .degraded || $0.state == .unavailable })
        {
            lifecycle = .degraded
        } else {
            lifecycle = requestedLifecycle
        }

        return HealthSnapshot(
            protocolVersion: .v1,
            serviceVersion: serviceVersion,
            lifecycle: lifecycle,
            processStartedAt: processStartedAt,
            generatedAt: generatedAt,
            uptimeSeconds: max(0, uptimeSeconds),
            revision: revision,
            components: components.sorted { $0.component.rawValue < $1.component.rawValue },
            issues: issues
        )
    }

    /// Returns the components expected before their implementations exist.
    public static var initialComponents: [ComponentHealth] {
        ServiceComponent.allCases.map {
            ComponentHealth(
                component: $0,
                state: .notConfigured,
                summary: "Not configured"
            )
        }
    }
}
