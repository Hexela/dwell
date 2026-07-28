// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellHistory
import DwellMQTT
import DwellSchemas
import Foundation

/// Persists ordinary client commands before publishing them to MQTT.
actor DeviceCommandDispatcher {
    private var installationID: DwellIdentifier?
    private var history: HistoryStore?
    private var brokerSession: BrokerSession?

    func configure(
        installationID: DwellIdentifier,
        history: HistoryStore,
        brokerSession: BrokerSession
    ) {
        self.installationID = installationID
        self.history = history
        self.brokerSession = brokerSession
    }

    func submit(
        _ request: DeviceCommandRequest
    ) async throws -> DeviceCommandAcceptance {
        guard request.capability == "light.on"
                || request.capability == "light.level",
              let installationID,
              let history,
              let brokerSession
        else {
            throw DeviceCommandError.unsupportedOrUnavailable
        }

        let commandID = request.idempotencyKey.uuidString.lowercased()
        let now = Date()
        let topic = [
            "dwell/v1/i", installationID.rawValue, "device",
            request.deviceID.rawValue, "component",
            request.componentID.rawValue, "command", request.capability,
        ].joined(separator: "/")
        let payload = try Self.payload(
            request: request,
            installationID: installationID,
            commandID: commandID,
            now: now
        )
        let canonicalTopic = try CanonicalTopic(parsing: topic)
        let message = try CanonicalMessageDecoder().decode(
            payload,
            for: canonicalTopic,
            now: now
        )
        let publication = MQTTMessage(
            topic: topic,
            payload: payload,
            qualityOfService: 1,
            isRetained: false,
            isDuplicate: false
        )
        _ = try await history.ingest(
            message,
            publication: publication,
            receivedAt: now
        )
        try await brokerSession.publish(payload, to: topic)
        return DeviceCommandAcceptance(
            commandID: commandID,
            wasPublished: true
        )
    }

    func commandSnapshots(
        now: Date = Date()
    ) async throws -> [DeviceCommandSnapshot] {
        guard let history else {
            return []
        }
        return try await history.commandSnapshots(now: now)
    }

    private static func payload(
        request: DeviceCommandRequest,
        installationID: DwellIdentifier,
        commandID: String,
        now: Date
    ) throws -> Data {
        let timestamp = now.formatted(
            .iso8601
                .year().month().day()
                .time(includingFractionalSeconds: true)
                .timeZone(separator: .omitted)
        )
        let expiresAt = now.addingTimeInterval(10).formatted(
            .iso8601
                .year().month().day()
                .time(includingFractionalSeconds: true)
                .timeZone(separator: .omitted)
        )
        let value: Any = switch request.value {
        case let .number(number, _): number
        case let .boolean(boolean): boolean
        case let .text(text): text
        }
        return try JSONSerialization.data(withJSONObject: [
            "schema": "io.dwell.command/1.0",
            "messageId": commandID,
            "source": [
                "installationId": installationID.rawValue,
                "integrationId": "dwell-core",
            ],
            "publishedAt": timestamp,
            "quality": ["status": "good"],
            "body": [
                "commandId": commandID,
                "operation": "set",
                "value": value,
                "expiresAt": expiresAt,
                "origin": ["kind": "user"],
                "risk": "ordinary",
            ],
        ])
    }
}

enum DeviceCommandError: Error {
    case unsupportedOrUnavailable
}
