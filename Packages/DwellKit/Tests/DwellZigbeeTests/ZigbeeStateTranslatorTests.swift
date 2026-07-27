// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellSchemas
import DwellZigbee
import Foundation
import Testing

@Suite("Zigbee2MQTT translation")
struct ZigbeeStateTranslatorTests {
    @Test("Discovery becomes retained canonical availability")
    func discoveryBecomesAvailability() throws {
        let translation = try ZigbeeStateTranslator().translateDiscovery(
            installationID: DwellIdentifier(rawValue: "home-a")!,
            deviceID: DwellIdentifier(rawValue: "zb-00124b00251c7e9d")!
        )

        #expect(
            translation.topic
                == "dwell/v1/i/home-a/device/zb-00124b00251c7e9d/availability"
        )
        let body = try JSONSerialization.jsonObject(with: translation.payload)
            as? [String: Any]
        #expect(body?["schema"] as? String == "io.dwell.availability/1.0")
        #expect(
            (body?["body"] as? [String: Any])?["status"] as? String
                == "unknown"
        )
    }

    @Test("Temperature and dimmable light state become canonical publications")
    func translatesUsefulDeviceState() throws {
        let installation = try #require(DwellIdentifier(rawValue: "home-a"))
        let device = try #require(DwellIdentifier(rawValue: "kitchen-light"))
        let payload = Data(
            #"{"temperature":21.4,"state":"ON","brightness":127}"#.utf8
        )

        let result = try ZigbeeStateTranslator().translate(
            payload,
            installationID: installation,
            deviceID: device,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(result.count == 3)
        #expect(result.map(\.topic).contains {
            $0.hasSuffix("/state/sensor.temperature")
        })
        #expect(result.map(\.topic).contains {
            $0.hasSuffix("/state/light.level")
        })
        for publication in result {
            let topic = try CanonicalTopic(parsing: publication.topic)
            _ = try CanonicalMessageDecoder().decode(
                publication.payload,
                for: topic,
                now: Date(timeIntervalSince1970: 1_700_000_001)
            )
        }
    }
}
