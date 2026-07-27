// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation
import Testing

struct HealthSnapshotTests {
    @Test func unconfiguredComponentsDoNotDegradeReadiness() {
        let snapshot = makeSnapshot(components: HealthSnapshotBuilder.initialComponents)

        #expect(snapshot.lifecycle == .ready)
        #expect(snapshot.components.count == ServiceComponent.allCases.count)
        #expect(snapshot.components.allSatisfy { $0.state == .notConfigured })
    }

    @Test func unavailableComponentDegradesReadyService() {
        let component = ComponentHealth(
            component: .broker,
            state: .unavailable,
            summary: "Broker connection failed"
        )

        let snapshot = makeSnapshot(components: [component])

        #expect(snapshot.lifecycle == .degraded)
    }

    @Test func incompatibleMajorVersionIsRejected() {
        #expect(ServiceProtocolVersion.v1.isCompatible(with: .init(major: 2, minor: 0)) == false)
        #expect(ServiceProtocolVersion.v1.isCompatible(with: .init(major: 1, minor: 8)))
    }

    @Test func inProcessClientReturnsInjectedSnapshot() async throws {
        let expected = makeSnapshot(components: [])
        let client = InProcessDwellServiceClient {
            expected
        }

        let snapshot = try await client.healthSnapshot()

        #expect(snapshot == expected)
    }

    private func makeSnapshot(components: [ComponentHealth]) -> HealthSnapshot {
        HealthSnapshotBuilder.makeSnapshot(
            serviceVersion: "0.1.0",
            requestedLifecycle: .ready,
            processStartedAt: Date(timeIntervalSince1970: 100),
            generatedAt: Date(timeIntervalSince1970: 105),
            uptimeSeconds: 5,
            revision: 1,
            components: components,
            issues: []
        )
    }
}
