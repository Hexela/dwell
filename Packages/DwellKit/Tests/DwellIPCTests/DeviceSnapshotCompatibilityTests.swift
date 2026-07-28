// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import Foundation
import Testing

struct DeviceSnapshotCompatibilityTests {
    @Test("Snapshots from the previous daemon decode with safe defaults")
    func previousSnapshotDecodes() throws {
        let component = try #require(DwellIdentifier(rawValue: "main"))
        let device = try #require(DwellIdentifier(rawValue: "kitchen-light"))
        let current = DeviceCollectionSnapshot(
            revision: 4,
            devices: [
                DeviceSnapshot(
                    deviceID: device,
                    displayName: "Kitchen Light",
                    availability: "online",
                    capabilities: [
                        CapabilitySnapshot(
                            componentID: component,
                            capability: "light.on",
                            value: .boolean(true),
                            observedAt: Date(timeIntervalSince1970: 100),
                            revision: 4,
                            isStale: false,
                            displayName: "Power",
                            isWritable: true
                        ),
                    ],
                    manufacturer: "Acme",
                    model: "One",
                    revision: 4
                ),
            ]
        )
        let encoded = try JSONEncoder().encode(current)
        var root = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var devices = try #require(root["devices"] as? [[String: Any]])
        var oldDevice = try #require(devices.first)
        oldDevice["manufacturer"] = nil
        oldDevice["model"] = nil
        oldDevice["commands"] = nil
        var capabilities = try #require(
            oldDevice["capabilities"] as? [[String: Any]]
        )
        var oldCapability = try #require(capabilities.first)
        oldCapability["displayName"] = nil
        oldCapability["isWritable"] = nil
        oldCapability["minimum"] = nil
        oldCapability["maximum"] = nil
        capabilities[0] = oldCapability
        oldDevice["capabilities"] = capabilities
        devices[0] = oldDevice
        root["devices"] = devices

        let legacyData = try JSONSerialization.data(withJSONObject: root)
        let decoded = try JSONDecoder().decode(
            DeviceCollectionSnapshot.self,
            from: legacyData
        )
        let decodedDevice = try #require(decoded.devices.first)
        let decodedCapability = try #require(
            decodedDevice.capabilities.first
        )
        #expect(decodedDevice.deviceID == device)
        #expect(decodedDevice.commands.isEmpty)
        #expect(decodedDevice.manufacturer == nil)
        #expect(decodedCapability.displayName == "light.on")
        #expect(decodedCapability.isWritable == false)
    }
}
