// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellRegistry
import DwellSchemas
import DwellZigbee
import Foundation
import Testing

@Suite("Device registry")
struct DeviceRegistryTests {
    @Test("State is reduced and older observations are ignored")
    func stateReduction() async throws {
        let registry = DeviceRegistry()
        let topic = try CanonicalTopic(
            parsing: "dwell/v1/i/home-a/device/sensor/component/main/state/sensor.temperature"
        )
        let decoder = CanonicalMessageDecoder()
        let newer = try decoder.decode(
            try fixture(named: "temperature"),
            for: topic
        )
        await registry.ingest(newer, from: topic)

        let snapshot = await registry.snapshot()
        #expect(snapshot.devices.count == 1)
        #expect(snapshot.devices.first?.deviceID.rawValue == "sensor")
        #expect(snapshot.devices.first?.capabilities.count == 1)
        #expect(snapshot.devices.first?.capabilities.first?.value == .number(21.4, unit: "cel"))
    }

    @Test("Metadata enriches a device without changing its stable identity")
    func metadataEnrichesDevice() async throws {
        let registry = DeviceRegistry()
        let installation = try #require(DwellIdentifier(rawValue: "home-a"))
        let device = try #require(DwellIdentifier(rawValue: "zb-001"))
        let translation = try ZigbeeStateTranslator().translateMetadata(
            ZigbeeDeviceMetadata(
                deviceName: "Kitchen light",
                manufacturer: "Acme",
                model: "A1",
                exposesLightOn: true
            ),
            installationID: installation,
            deviceID: device
        )
        let topic = try CanonicalTopic(parsing: translation.topic)
        let message = try CanonicalMessageDecoder().decode(
            translation.payload,
            for: topic
        )
        await registry.ingest(message, from: topic)

        let snapshot = try #require(await registry.snapshot().devices.first)
        #expect(snapshot.deviceID == device)
        #expect(snapshot.displayName == "Kitchen light")
        #expect(snapshot.manufacturer == "Acme")
        #expect(snapshot.model == "A1")
    }

    private func fixture(named name: String) throws -> Data {
        var root = URL(filePath: #filePath)
        for _ in 0..<5 {
            root.deleteLastPathComponent()
        }
        return try Data(
            contentsOf: root.appending(
                path: "Tests/Fixtures/MQTT/v1/valid/\(name).json"
            )
        )
    }
}
