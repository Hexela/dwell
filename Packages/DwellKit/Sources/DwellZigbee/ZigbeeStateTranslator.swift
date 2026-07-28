// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import Foundation

/// A canonical publication produced from one Zigbee2MQTT state payload.
public struct ZigbeeTranslation: Equatable, Sendable {
    public let topic: String
    public let payload: Data

    public init(topic: String, payload: Data) {
        self.topic = topic
        self.payload = payload
    }
}

/// Discovery information used to publish canonical component metadata.
public struct ZigbeeDeviceMetadata: Equatable, Sendable {
    public let deviceName: String
    public let manufacturer: String?
    public let model: String?
    public let exposesTemperature: Bool
    public let exposesLightOn: Bool
    public let exposesLightLevel: Bool

    public init(
        deviceName: String,
        manufacturer: String? = nil,
        model: String? = nil,
        exposesTemperature: Bool = false,
        exposesLightOn: Bool = false,
        exposesLightLevel: Bool = false
    ) {
        self.deviceName = deviceName
        self.manufacturer = manufacturer
        self.model = model
        self.exposesTemperature = exposesTemperature
        self.exposesLightOn = exposesLightOn
        self.exposesLightLevel = exposesLightLevel
    }
}

/// Converts the first supported Zigbee2MQTT state capabilities to canonical MQTT.
public struct ZigbeeStateTranslator: Sendable {
    public init() {}

    public func translateMetadata(
        _ metadata: ZigbeeDeviceMetadata,
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        observedAt: Date = Date()
    ) throws -> ZigbeeTranslation {
        var capabilities: [[String: Any]] = []
        if metadata.exposesTemperature {
            capabilities.append([
                "capability": "sensor.temperature",
                "displayName": "Temperature",
                "valueKind": "quantity",
                "isWritable": false,
                "unit": "cel",
            ])
        }
        if metadata.exposesLightOn {
            capabilities.append([
                "capability": "light.on",
                "displayName": "Power",
                "valueKind": "boolean",
                "isWritable": true,
            ])
        }
        if metadata.exposesLightLevel {
            capabilities.append([
                "capability": "light.level",
                "displayName": "Brightness",
                "valueKind": "level",
                "isWritable": true,
                "minimum": 0,
                "maximum": 1,
            ])
        }
        var body: [String: Any] = [
            "deviceName": metadata.deviceName,
            "componentName": "Main",
            "capabilities": capabilities,
        ]
        if let manufacturer = metadata.manufacturer {
            body["manufacturer"] = manufacturer
        }
        if let model = metadata.model {
            body["model"] = model
        }
        return try makeEnvelope(
            installationID: installationID,
            deviceID: deviceID,
            route: "metadata",
            schema: "io.dwell.device-metadata/1.0",
            body: body,
            observedAt: observedAt
        )
    }

    public func translateAcknowledgement(
        commandID: String,
        capability: String,
        status: String,
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        observedAt: Date = Date()
    ) throws -> ZigbeeTranslation {
        let timestamp = Self.timestamp(observedAt)
        let envelope: [String: Any] = [
            "schema": "io.dwell.command-ack/1.0",
            "messageId": UUID().uuidString.lowercased(),
            "source": [
                "installationId": installationID.rawValue,
                "integrationId": "zigbee-main",
            ],
            "observedAt": timestamp,
            "publishedAt": timestamp,
            "quality": ["status": "good"],
            "causationId": commandID,
            "body": [
                "commandId": commandID,
                "status": status,
            ],
        ]
        return ZigbeeTranslation(
            topic: "dwell/v1/i/\(installationID.rawValue)/device/\(deviceID.rawValue)/component/main/ack/\(capability)",
            payload: try JSONSerialization.data(withJSONObject: envelope)
        )
    }

    /// Creates a canonical unknown-availability fact when Zigbee2MQTT
    /// discovers a device before the sleeping device next reports state.
    public func translateDiscovery(
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        observedAt: Date = Date()
    ) throws -> ZigbeeTranslation {
        let timestamp = Self.timestamp(observedAt)
        let envelope: [String: Any] = [
            "schema": "io.dwell.availability/1.0",
            "messageId": UUID().uuidString.lowercased(),
            "source": [
                "installationId": installationID.rawValue,
                "integrationId": "zigbee-main",
            ],
            "observedAt": timestamp,
            "publishedAt": timestamp,
            "quality": ["status": "good"],
            "body": [
                "status": "unknown",
                "reason": "Discovered by Zigbee2MQTT",
            ],
        ]
        return ZigbeeTranslation(
            topic: "dwell/v1/i/\(installationID.rawValue)/device/\(deviceID.rawValue)/availability",
            payload: try JSONSerialization.data(withJSONObject: envelope)
        )
    }

    /// Translates temperature, on/off, and brightness fields.
    public func translate(
        _ payload: Data,
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        observedAt: Date = Date()
    ) throws -> [ZigbeeTranslation] {
        guard let object = try JSONSerialization.jsonObject(with: payload)
            as? [String: Any]
        else {
            throw ZigbeeTranslationError.invalidPayload
        }

        var result: [ZigbeeTranslation] = []
        if let temperature = object["temperature"] as? NSNumber {
            result.append(
                try makeTranslation(
                    installationID: installationID,
                    deviceID: deviceID,
                    capability: "sensor.temperature",
                    schema: "io.dwell.state.quantity/1.0",
                    body: ["value": temperature.doubleValue, "unit": "cel"],
                    observedAt: observedAt
                )
            )
        }
        if let state = object["state"] as? String,
           state == "ON" || state == "OFF"
        {
            result.append(
                try makeTranslation(
                    installationID: installationID,
                    deviceID: deviceID,
                    capability: "light.on",
                    schema: "io.dwell.state.boolean/1.0",
                    body: ["value": state == "ON"],
                    observedAt: observedAt
                )
            )
        }
        if let brightness = object["brightness"] as? NSNumber {
            let level = min(max(brightness.doubleValue / 254, 0), 1)
            result.append(
                try makeTranslation(
                    installationID: installationID,
                    deviceID: deviceID,
                    capability: "light.level",
                    schema: "io.dwell.state.level/1.0",
                    body: [
                        "value": level,
                        "range": ["minimum": 0, "maximum": 1],
                    ],
                    observedAt: observedAt
                )
            )
        }
        return result
    }

    private func makeTranslation(
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        capability: String,
        schema: String,
        body: [String: Any],
        observedAt: Date
    ) throws -> ZigbeeTranslation {
        let timestamp = Self.timestamp(observedAt)
        let envelope: [String: Any] = [
            "schema": schema,
            "messageId": UUID().uuidString.lowercased(),
            "source": [
                "installationId": installationID.rawValue,
                "integrationId": "zigbee-main",
            ],
            "observedAt": timestamp,
            "publishedAt": timestamp,
            "quality": ["status": "good"],
            "body": body,
        ]
        return ZigbeeTranslation(
            topic: "dwell/v1/i/\(installationID.rawValue)/device/\(deviceID.rawValue)/component/main/state/\(capability)",
            payload: try JSONSerialization.data(withJSONObject: envelope)
        )
    }

    private func makeEnvelope(
        installationID: DwellIdentifier,
        deviceID: DwellIdentifier,
        route: String,
        schema: String,
        body: [String: Any],
        observedAt: Date
    ) throws -> ZigbeeTranslation {
        let timestamp = Self.timestamp(observedAt)
        let envelope: [String: Any] = [
            "schema": schema,
            "messageId": UUID().uuidString.lowercased(),
            "source": [
                "installationId": installationID.rawValue,
                "integrationId": "zigbee-main",
            ],
            "observedAt": timestamp,
            "publishedAt": timestamp,
            "quality": ["status": "good"],
            "body": body,
        ]
        return ZigbeeTranslation(
            topic: "dwell/v1/i/\(installationID.rawValue)/device/\(deviceID.rawValue)/component/main/\(route)",
            payload: try JSONSerialization.data(withJSONObject: envelope)
        )
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .time(includingFractionalSeconds: true)
                .timeZone(separator: .omitted)
        )
    }
}

public enum ZigbeeTranslationError: String, Error, Sendable {
    case invalidPayload = "invalid-zigbee-payload"
}
