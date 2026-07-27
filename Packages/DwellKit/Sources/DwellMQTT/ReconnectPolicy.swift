// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// Computes bounded exponential reconnect delays.
public struct ReconnectPolicy: Sendable {
    public let initialDelay: Duration
    public let maximumDelay: Duration

    /// Creates a reconnect policy.
    public init(
        initialDelay: Duration = .seconds(1),
        maximumDelay: Duration = .seconds(60)
    ) {
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
    }

    /// Returns the delay before a numbered retry.
    public func delay(
        forAttempt attempt: UInt,
        jitterUnitInterval: Double = 0.5
    ) -> Duration {
        precondition((0...1).contains(jitterUnitInterval))
        let exponent = min(attempt, 6)
        let multiplier = 1 << exponent
        let base = min(initialDelay * multiplier, maximumDelay)
        let baseSeconds = Self.seconds(in: base)
        let maximumSeconds = Self.seconds(in: maximumDelay)
        let factor = 0.8 + (jitterUnitInterval * 0.4)
        let jitteredSeconds = min(baseSeconds * factor, maximumSeconds)
        return .nanoseconds(Int64(jitteredSeconds * 1_000_000_000))
    }

    private static func seconds(in duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

/// Suspends reconnect attempts without coupling the session to a concrete clock.
public protocol BrokerSleeper: Sendable {
    /// Suspends for the supplied duration.
    func sleep(for duration: Duration) async throws
}

/// The production continuous-clock sleeper.
public struct ContinuousBrokerSleeper: BrokerSleeper {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
