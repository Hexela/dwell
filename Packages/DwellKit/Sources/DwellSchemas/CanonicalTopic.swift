// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain

/// A registered canonical capability name composed of dot-separated Dwell
/// identifiers.
public struct CapabilityName: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    /// Creates a capability name when every dot-separated component is a valid
    /// Dwell identifier.
    ///
    /// - Parameter rawValue: The canonical capability name.
    public init?(rawValue: String) {
        let components = rawValue.split(separator: ".", omittingEmptySubsequences: false)
        guard components.isEmpty == false,
              components.allSatisfy({ DwellIdentifier(rawValue: String($0)) != nil })
        else {
            return nil
        }

        self.rawValue = rawValue
    }
}

/// A parsed MQTT topic in Dwell's canonical v1 namespace.
public struct CanonicalTopic: Hashable, Sendable {
    /// The message route encoded by a canonical topic.
    public enum Route: Hashable, Sendable {
        case deviceMetadata(device: DwellIdentifier, component: DwellIdentifier)
        case deviceState(
            device: DwellIdentifier,
            component: DwellIdentifier,
            capability: CapabilityName
        )
        case deviceCommand(
            device: DwellIdentifier,
            component: DwellIdentifier,
            capability: CapabilityName
        )
        case deviceAcknowledgement(
            device: DwellIdentifier,
            component: DwellIdentifier,
            capability: CapabilityName
        )
        case deviceEvent(
            device: DwellIdentifier,
            component: DwellIdentifier,
            event: DwellIdentifier
        )
        case deviceAvailability(device: DwellIdentifier)
        case integrationMetadata(integration: DwellIdentifier)
        case integrationDiscovery(integration: DwellIdentifier)
        case integrationStatus(integration: DwellIdentifier)
        case sceneCommand(scene: DwellIdentifier)
        case notificationRequest
        case automationEvent(automation: DwellIdentifier)
        case systemStatus
    }

    public let installation: DwellIdentifier
    public let route: Route

    /// Parses and validates a canonical MQTT v1 topic.
    ///
    /// - Parameter rawValue: The complete MQTT topic.
    /// - Throws: ``CanonicalTopicError`` when the topic is outside the v1
    ///   namespace, contains an invalid identifier, or does not name a
    ///   supported route.
    public init(parsing rawValue: String) throws {
        let segments = rawValue.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard segments.count >= 4,
              segments[0] == "dwell",
              segments[1] == "v1",
              segments[2] == "i"
        else {
            throw CanonicalTopicError.invalidNamespace
        }

        installation = try Self.identifier(segments[3])
        route = try Self.parseRoute(Array(segments.dropFirst(4)))
    }

    private static func parseRoute(_ segments: [String]) throws -> Route {
        if segments.count == 5,
           segments[0] == "device",
           segments[2] == "component",
           segments[4] == "metadata"
        {
            return .deviceMetadata(
                device: try identifier(segments[1]),
                component: try identifier(segments[3])
            )
        }

        if segments.count == 6,
           segments[0] == "device",
           segments[2] == "component"
        {
            let device = try identifier(segments[1])
            let component = try identifier(segments[3])

            switch segments[4] {
            case "state":
                return .deviceState(
                    device: device,
                    component: component,
                    capability: try capabilityName(segments[5])
                )
            case "command":
                return .deviceCommand(
                    device: device,
                    component: component,
                    capability: try capabilityName(segments[5])
                )
            case "ack":
                return .deviceAcknowledgement(
                    device: device,
                    component: component,
                    capability: try capabilityName(segments[5])
                )
            case "event":
                return .deviceEvent(
                    device: device,
                    component: component,
                    event: try identifier(segments[5])
                )
            default:
                break
            }
        }

        if segments.count == 3 {
            switch (segments[0], segments[2]) {
            case ("device", "availability"):
                return .deviceAvailability(device: try identifier(segments[1]))
            case ("integration", "metadata"):
                return .integrationMetadata(integration: try identifier(segments[1]))
            case ("integration", "discovery"):
                return .integrationDiscovery(integration: try identifier(segments[1]))
            case ("integration", "status"):
                return .integrationStatus(integration: try identifier(segments[1]))
            case ("scene", "command"):
                return .sceneCommand(scene: try identifier(segments[1]))
            case ("automation", "event"):
                return .automationEvent(automation: try identifier(segments[1]))
            default:
                break
            }
        }

        if segments == ["notification", "request"] {
            return .notificationRequest
        }

        if segments == ["system", "status"] {
            return .systemStatus
        }

        throw CanonicalTopicError.unsupportedRoute
    }

    private static func identifier(_ value: String) throws -> DwellIdentifier {
        guard let identifier = DwellIdentifier(rawValue: value) else {
            throw CanonicalTopicError.invalidIdentifier(value)
        }

        return identifier
    }

    private static func capabilityName(_ value: String) throws -> CapabilityName {
        guard let capability = CapabilityName(rawValue: value) else {
            throw CanonicalTopicError.invalidCapability(value)
        }

        return capability
    }
}

/// An error found while parsing a canonical MQTT topic.
public enum CanonicalTopicError: Error, Equatable, Sendable {
    /// The topic does not begin with the supported `dwell/v1/i` namespace.
    case invalidNamespace

    /// A route identifier does not satisfy the Dwell identifier grammar.
    case invalidIdentifier(String)

    /// A capability name is not composed of valid dot-separated identifiers.
    case invalidCapability(String)

    /// The namespace is valid, but its remaining path is not a canonical route.
    case unsupportedRoute
}
