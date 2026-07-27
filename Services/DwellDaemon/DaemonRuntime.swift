// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import DwellMQTT
import Foundation
import Synchronization

/// Owns the daemon lifecycle and component health used to create snapshots.
final class DaemonRuntime: Sendable {
    private struct State: Sendable {
        var lifecycle: ServiceLifecycleState = .starting
        var revision: UInt64 = 0
        var components: [ServiceComponent: ComponentHealth]
        var issues: [HealthIssue] = []
    }

    private let state: Mutex<State>
    private let serviceVersion: String
    private let processStartedAt: Date
    private let processStartedUptime: TimeInterval

    init(
        serviceVersion: String,
        processStartedAt: Date = Date(),
        processStartedUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        self.serviceVersion = serviceVersion
        self.processStartedAt = processStartedAt
        self.processStartedUptime = processStartedUptime
        state = Mutex(
            State(
                components: Dictionary(
                    uniqueKeysWithValues: HealthSnapshotBuilder.initialComponents.map {
                        ($0.component, $0)
                    }
                )
            )
        )
    }

    func markReady() {
        state.withLock {
            $0.lifecycle = .ready
            $0.revision += 1
        }
    }

    func markStopping() {
        state.withLock {
            $0.lifecycle = .stopping
            $0.revision += 1
        }
    }

    func enterSafeMode(issue: HealthIssue) {
        state.withLock {
            $0.lifecycle = .safeMode
            if $0.issues.contains(where: { $0.id == issue.id }) == false {
                $0.issues.append(issue)
            }
            $0.revision += 1
        }
    }

    func update(_ health: ComponentHealth) {
        state.withLock {
            $0.components[health.component] = health
            $0.revision += 1
        }
    }

    func updateBrokerStatus(_ status: BrokerStatus) {
        let health: ComponentHealth
        switch status.state {
        case .disabled:
            health = ComponentHealth(
                component: .broker,
                state: .notConfigured,
                summary: "Not configured"
            )
        case .connecting:
            health = ComponentHealth(
                component: .broker,
                state: .degraded,
                summary: "Connecting"
            )
        case .online:
            health = ComponentHealth(
                component: .broker,
                state: .healthy,
                summary: [
                    "Online",
                    "\(status.acceptedMessageCount) accepted",
                    "\(status.duplicateMessageCount) duplicates",
                    "\(status.rejectedMessageCount) rejected",
                ].joined(separator: " · ")
            )
        case .reconnecting:
            health = ComponentHealth(
                component: .broker,
                state: .degraded,
                summary: "Reconnecting (attempt \(status.reconnectCount))"
            )
        case .stopped:
            health = ComponentHealth(
                component: .broker,
                state: .unavailable,
                summary: "Stopped"
            )
        }
        update(health)
    }

    func snapshot(
        generatedAt: Date = Date(),
        systemUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> HealthSnapshot {
        state.withLock {
            HealthSnapshotBuilder.makeSnapshot(
                serviceVersion: serviceVersion,
                requestedLifecycle: $0.lifecycle,
                processStartedAt: processStartedAt,
                generatedAt: generatedAt,
                uptimeSeconds: systemUptime - processStartedUptime,
                revision: $0.revision,
                components: Array($0.components.values),
                issues: $0.issues
            )
        }
    }
}
