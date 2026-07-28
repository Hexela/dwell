// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation
import Testing

struct AdapterSupervisorTests {
    @Test("Restart delay is exponential, bounded, and eventually stops")
    func restartPolicy() {
        let policy = AdapterRestartPolicy(
            maximumConsecutiveRestarts: 4,
            initialDelay: .seconds(1),
            maximumDelay: .seconds(3)
        )

        #expect(policy.delay(after: 1) == .seconds(1))
        #expect(policy.delay(after: 2) == .seconds(2))
        #expect(policy.delay(after: 3) == .seconds(3))
        #expect(policy.delay(after: 4) == .seconds(3))
        #expect(policy.delay(after: 5) == nil)
    }
}
