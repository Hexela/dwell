// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation
import Testing

struct DaemonRuntimeTests {
    @Test func startsBeforeBecomingReady() {
        let runtime = makeRuntime()

        #expect(runtime.snapshot(systemUptime: 12).lifecycle == .starting)

        runtime.markReady()

        let snapshot = runtime.snapshot(systemUptime: 13)
        #expect(snapshot.lifecycle == .ready)
        #expect(snapshot.revision == 1)
        #expect(snapshot.uptimeSeconds == 3)
    }

    @Test func componentFailureDegradesReadyRuntime() {
        let runtime = makeRuntime()
        runtime.markReady()
        runtime.update(
            ComponentHealth(
                component: .broker,
                state: .unavailable,
                summary: "Connection failed"
            )
        )

        let snapshot = runtime.snapshot(systemUptime: 15)

        #expect(snapshot.lifecycle == .degraded)
        #expect(snapshot.revision == 2)
    }

    private func makeRuntime() -> DaemonRuntime {
        DaemonRuntime(
            serviceVersion: "0.1.0",
            processStartedAt: Date(timeIntervalSince1970: 100),
            processStartedUptime: 10
        )
    }
}
