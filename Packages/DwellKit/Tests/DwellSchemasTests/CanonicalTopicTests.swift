// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain
import DwellSchemas
import Testing

struct CanonicalTopicTests {
    @Test("Parses every canonical v1 route", arguments: routeFixtures)
    func parsesCanonicalRoute(fixture: RouteFixture) throws {
        let topic = try CanonicalTopic(parsing: fixture.topic)

        #expect(topic.installation == DwellIdentifier(rawValue: "home-a"))
        #expect(topic.route == fixture.route)
    }

    @Test(
        "Rejects topics outside the canonical v1 namespace",
        arguments: [
            "",
            "other/v1/i/home-a/system/status",
            "dwell/v2/i/home-a/system/status",
            "dwell/v1/home-a/system/status",
        ]
    )
    func rejectsInvalidNamespace(topic: String) {
        #expect(throws: CanonicalTopicError.invalidNamespace) {
            try CanonicalTopic(parsing: topic)
        }
    }

    @Test(
        "Rejects malformed route identifiers",
        arguments: [
            "dwell/v1/i/Home/device/light/component/main/state/light.on",
            "dwell/v1/i/home-a/device/light_1/component/main/state/light.on",
            "dwell/v1/i/home-a/device/light/component//state/light.on",
        ]
    )
    func rejectsInvalidIdentifier(topic: String) {
        do {
            _ = try CanonicalTopic(parsing: topic)
            Issue.record("Expected an invalid identifier error.")
        } catch CanonicalTopicError.invalidIdentifier {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test(
        "Rejects malformed capability names",
        arguments: [
            "dwell/v1/i/home-a/device/light/component/main/state/Light.on",
            "dwell/v1/i/home-a/device/light/component/main/state/light..on",
            "dwell/v1/i/home-a/device/light/component/main/state/light_on",
        ]
    )
    func rejectsInvalidCapability(topic: String) {
        do {
            _ = try CanonicalTopic(parsing: topic)
            Issue.record("Expected an invalid capability error.")
        } catch CanonicalTopicError.invalidCapability {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test(
        "Rejects unsupported routes",
        arguments: [
            "dwell/v1/i/home-a/device/light",
            "dwell/v1/i/home-a/system/health",
            "dwell/v1/i/home-a/notification/request/extra",
            "dwell/v1/i/home-a/device/light/component/main/state/light.on/extra",
        ]
    )
    func rejectsUnsupportedRoute(topic: String) {
        #expect(throws: CanonicalTopicError.unsupportedRoute) {
            try CanonicalTopic(parsing: topic)
        }
    }
}

struct RouteFixture: Sendable, CustomTestStringConvertible {
    let topic: String
    let route: CanonicalTopic.Route

    var testDescription: String {
        topic
    }
}

let routeFixtures: [RouteFixture] = [
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/light/component/main/metadata",
        route: .deviceMetadata(device: id("light"), component: id("main"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/light/component/main/state/light.on",
        route: .deviceState(
            device: id("light"),
            component: id("main"),
            capability: capability("light.on")
        )
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/light/component/main/command/light.on",
        route: .deviceCommand(
            device: id("light"),
            component: id("main"),
            capability: capability("light.on")
        )
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/light/component/main/ack/light.on",
        route: .deviceAcknowledgement(
            device: id("light"),
            component: id("main"),
            capability: capability("light.on")
        )
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/doorbell/component/button/event/pressed",
        route: .deviceEvent(
            device: id("doorbell"),
            component: id("button"),
            event: id("pressed")
        )
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/device/light/availability",
        route: .deviceAvailability(device: id("light"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/integration/zigbee-main/metadata",
        route: .integrationMetadata(integration: id("zigbee-main"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/integration/zigbee-main/discovery",
        route: .integrationDiscovery(integration: id("zigbee-main"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/integration/zigbee-main/status",
        route: .integrationStatus(integration: id("zigbee-main"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/scene/goodnight/command",
        route: .sceneCommand(scene: id("goodnight"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/notification/request",
        route: .notificationRequest
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/automation/evening-light/event",
        route: .automationEvent(automation: id("evening-light"))
    ),
    RouteFixture(
        topic: "dwell/v1/i/home-a/system/status",
        route: .systemStatus
    ),
]

private func id(_ value: String) -> DwellIdentifier {
    guard let identifier = DwellIdentifier(rawValue: value) else {
        preconditionFailure("Invalid identifier fixture: \(value)")
    }

    return identifier
}

private func capability(_ value: String) -> CapabilityName {
    guard let capability = CapabilityName(rawValue: value) else {
        preconditionFailure("Invalid capability fixture: \(value)")
    }

    return capability
}
