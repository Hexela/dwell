// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The daemon's current lifecycle phase.
public enum ServiceLifecycleState: String, Codable, Sendable {
    case starting
    case ready
    case degraded
    case safeMode = "safe-mode"
    case stopping
}

/// A component represented in the daemon health snapshot.
public enum ServiceComponent: String, CaseIterable, Codable, Sendable {
    case broker
    case metadataStore = "metadata-store"
    case historyStore = "history-store"
    case scheduler
    case zigbeeAdapter = "zigbee-adapter"
}

/// The operational state of a daemon component.
public enum ComponentHealthState: String, Codable, Sendable {
    case healthy
    case degraded
    case unavailable
    case notConfigured = "not-configured"
}

/// Health information for one daemon component.
public struct ComponentHealth: Codable, Equatable, Identifiable, Sendable {
    public var id: ServiceComponent { component }

    public let component: ServiceComponent
    public let state: ComponentHealthState
    public let summary: String

    /// Creates a component health value.
    public init(
        component: ServiceComponent,
        state: ComponentHealthState,
        summary: String
    ) {
        self.component = component
        self.state = state
        self.summary = summary
    }
}

/// A stable health issue reported by the daemon.
public struct HealthIssue: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let summary: String

    /// Creates a health issue.
    public init(id: String, summary: String) {
        self.id = id
        self.summary = summary
    }
}

/// An immutable view of the daemon's current health.
public struct HealthSnapshot: Codable, Equatable, Sendable {
    public let protocolVersion: ServiceProtocolVersion
    public let serviceVersion: String
    public let lifecycle: ServiceLifecycleState
    public let processStartedAt: Date
    public let generatedAt: Date
    public let uptimeSeconds: Double
    public let revision: UInt64
    public let components: [ComponentHealth]
    public let issues: [HealthIssue]

    /// Creates a daemon health snapshot.
    public init(
        protocolVersion: ServiceProtocolVersion,
        serviceVersion: String,
        lifecycle: ServiceLifecycleState,
        processStartedAt: Date,
        generatedAt: Date,
        uptimeSeconds: Double,
        revision: UInt64,
        components: [ComponentHealth],
        issues: [HealthIssue]
    ) {
        self.protocolVersion = protocolVersion
        self.serviceVersion = serviceVersion
        self.lifecycle = lifecycle
        self.processStartedAt = processStartedAt
        self.generatedAt = generatedAt
        self.uptimeSeconds = uptimeSeconds
        self.revision = revision
        self.components = components
        self.issues = issues
    }
}
