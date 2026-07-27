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

/// Converts the first supported Zigbee2MQTT state capabilities to canonical MQTT.
public struct ZigbeeStateTranslator: Sendable {
    public init() {}

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
