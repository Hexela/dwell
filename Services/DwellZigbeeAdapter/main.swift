// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellMQTT
import DwellMQTTNIO
import DwellZigbee
import Darwin
import Foundation

try await ZigbeeAdapterRuntime.run()

private enum ZigbeeAdapterRuntime {
    static func run() async throws {
        guard let baseConfiguration = try loadConfiguration(),
              let installationID = DwellIdentifier(
                  rawValue: baseConfiguration.installationIdentifier
              )
        else {
            throw AdapterError.missingConfiguration
        }

        let baseTopic = ProcessInfo.processInfo.environment[
            "DWELL_ZIGBEE_BASE_TOPIC"
        ] ?? "zigbee2mqtt"
        let configuration = BrokerConfiguration(
            host: baseConfiguration.host,
            port: baseConfiguration.port,
            clientIdentifier: "\(baseConfiguration.clientIdentifier)-zigbee-v2",
            installationIdentifier: baseConfiguration.installationIdentifier,
            protocolVersion: baseConfiguration.protocolVersion,
            usesTLS: baseConfiguration.usesTLS,
            username: baseConfiguration.username,
            password: baseConfiguration.password,
            statusTopicOverride: "\(baseTopic)/dwell-adapter/status"
        )
        let transport = try await MQTTNIOTransportFactory().makeTransport(
            configuration: configuration,
            lastWillPayload: Data(#"{"status":"offline"}"#.utf8)
        )
        try await transport.connect()
        let messages = await transport.incomingMessages()
        try await transport.subscribe(to: "\(baseTopic)/bridge/devices")
        try await transport.subscribe(to: "\(baseTopic)/#")
        try await transport.subscribe(
            to: "dwell/v1/i/\(installationID.rawValue)/device/+/component/+/command/+"
        )
        try await transport.publish(
            Data(#"{"status":"online"}"#.utf8),
            to: configuration.statusTopic,
            retain: true
        )

        var directory = ZigbeeDeviceDirectory()
        var pendingState: [String: Data] = [:]
        var pendingCommands: [String: PendingCommand] = [:]
        let translator = ZigbeeStateTranslator()
        for try await message in messages {
            if message.topic == "\(baseTopic)/bridge/devices" {
                let discoveredDevices = directory.update(from: message.payload)
                for device in discoveredDevices {
                    let publication = try translator.translateDiscovery(
                        installationID: installationID,
                        deviceID: device.id
                    )
                    try await transport.publish(
                        publication.payload,
                        to: publication.topic,
                        retain: true
                    )
                    let metadata = try translator.translateMetadata(
                        device.metadata,
                        installationID: installationID,
                        deviceID: device.id
                    )
                    try await transport.publish(
                        metadata.payload,
                        to: metadata.topic,
                        retain: true
                    )
                }
                var translatedFriendlyNames: [String] = []
                for (friendlyName, payload) in pendingState {
                    guard let deviceID = directory.deviceID(
                        for: friendlyName
                    ) else {
                        continue
                    }
                    for publication in try translator.translate(
                        payload,
                        installationID: installationID,
                        deviceID: deviceID
                    ) {
                        try await transport.publish(
                            publication.payload,
                            to: publication.topic,
                            retain: true
                        )
                    }
                    translatedFriendlyNames.append(friendlyName)
                }
                for friendlyName in translatedFriendlyNames {
                    pendingState[friendlyName] = nil
                }
                continue
            }
            if message.topic.hasPrefix("dwell/v1/") {
                if let command = directory.zigbeeCommand(
                    from: message,
                    baseTopic: baseTopic
                ) {
                    pendingCommands[
                        "\(command.deviceID.rawValue)/\(command.capability)"
                    ] = PendingCommand(
                        commandID: command.commandID,
                        capability: command.capability
                    )
                    try await transport.publish(
                        command.payload,
                        to: command.topic,
                        retain: false
                    )
                    let acknowledgement = try translator.translateAcknowledgement(
                        commandID: command.commandID,
                        capability: command.capability,
                        status: "accepted",
                        installationID: installationID,
                        deviceID: command.deviceID
                    )
                    try await transport.publish(
                        acknowledgement.payload,
                        to: acknowledgement.topic,
                        retain: false
                    )
                }
                continue
            }

            let prefix = "\(baseTopic)/"
            guard message.topic.hasPrefix(prefix),
                  message.topic.hasSuffix("/availability") == false,
                  message.topic.contains("/bridge/") == false
            else {
                continue
            }
            let friendlyName = String(message.topic.dropFirst(prefix.count))
            guard friendlyName.contains("/") == false else {
                continue
            }
            guard let deviceID = directory.deviceID(for: friendlyName) else {
                pendingState[friendlyName] = message.payload
                continue
            }
            for publication in try translator.translate(
                message.payload,
                installationID: installationID,
                deviceID: deviceID
            ) {
                try await transport.publish(
                    publication.payload,
                    to: publication.topic,
                    retain: true
                )
            }
            for capability in Self.reportedCapabilities(in: message.payload) {
                let key = "\(deviceID.rawValue)/\(capability)"
                guard let command = pendingCommands.removeValue(forKey: key) else {
                    continue
                }
                let acknowledgement = try translator.translateAcknowledgement(
                    commandID: command.commandID,
                    capability: command.capability,
                    status: "applied",
                    installationID: installationID,
                    deviceID: deviceID
                )
                try await transport.publish(
                    acknowledgement.payload,
                    to: acknowledgement.topic,
                    retain: false
                )
            }
        }
        await transport.disconnect()
    }

    private static func reportedCapabilities(in payload: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: payload)
            as? [String: Any]
        else {
            return []
        }
        var result: [String] = []
        if object["state"] != nil {
            result.append("light.on")
        }
        if object["brightness"] != nil {
            result.append("light.level")
        }
        return result
    }

    private static func loadConfiguration() throws -> BrokerConfiguration? {
        let executableDirectory = resolvedExecutableDirectory()
        let bundled = executableDirectory.appending(
            path: "development-broker.json"
        )
        let configured = ProcessInfo.processInfo.environment[
            "DWELL_BROKER_CONFIGURATION"
        ].map { URL(filePath: $0) }
        guard let url = configured ?? (
            FileManager.default.fileExists(atPath: bundled.path()) ? bundled : nil
        ) else {
            return nil
        }
        return try JSONDecoder().decode(
            BrokerConfiguration.self,
            from: Data(contentsOf: url)
        )
    }

    private static func resolvedExecutableDirectory() -> URL {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        let result = buffer.withUnsafeMutableBufferPointer {
            _NSGetExecutablePath($0.baseAddress, &size)
        }
        guard result == 0 else {
            return URL(filePath: CommandLine.arguments[0])
                .standardizedFileURL
                .deletingLastPathComponent()
        }
        let path = String(
            decoding: buffer.prefix { $0 != 0 }.map {
                UInt8(bitPattern: $0)
            },
            as: UTF8.self
        )
        return URL(filePath: path)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
    }
}

private struct PendingCommand {
    let commandID: String
    let capability: String
}

private struct DiscoveredDevice {
    let id: DwellIdentifier
    let metadata: ZigbeeDeviceMetadata
}

private struct ZigbeeDeviceDirectory {
    private var deviceByFriendlyName: [String: DwellIdentifier] = [:]
    private var friendlyNameByDevice: [DwellIdentifier: String] = [:]

    mutating func update(from payload: Data) -> [DiscoveredDevice] {
        guard let devices = try? JSONSerialization.jsonObject(with: payload)
            as? [[String: Any]]
        else {
            return []
        }
        var discoveredDevices: [DiscoveredDevice] = []
        for device in devices {
            guard let friendlyName = device["friendly_name"] as? String,
                  let ieeeAddress = device["ieee_address"] as? String,
                  let identifier = Self.identifier(from: ieeeAddress)
            else {
                continue
            }
            deviceByFriendlyName[friendlyName] = identifier
            friendlyNameByDevice[identifier] = friendlyName
            if device["type"] as? String != "Coordinator" {
                discoveredDevices.append(
                    DiscoveredDevice(
                        id: identifier,
                        metadata: Self.metadata(
                            from: device,
                            friendlyName: friendlyName
                        )
                    )
                )
            }
        }
        return discoveredDevices
    }

    func deviceID(for friendlyName: String) -> DwellIdentifier? {
        deviceByFriendlyName[friendlyName]
    }

    func zigbeeCommand(
        from message: MQTTMessage,
        baseTopic: String
    ) -> (
        topic: String,
        payload: Data,
        commandID: String,
        deviceID: DwellIdentifier,
        capability: String
    )? {
        let segments = message.topic.split(separator: "/").map(String.init)
        guard segments.count == 10,
              segments[4] == "device",
              let deviceID = DwellIdentifier(rawValue: segments[5]),
              let friendlyName = friendlyNameByDevice[deviceID],
              let envelope = try? JSONSerialization.jsonObject(
                  with: message.payload
              ) as? [String: Any],
              let body = envelope["body"] as? [String: Any]
              , let commandID = body["commandId"] as? String
        else {
            return nil
        }
        let capability = segments[9]
        let value = body["value"]
        let zigbeeBody: [String: Any]
        switch capability {
        case "light.on":
            guard let boolean = value as? Bool else { return nil }
            zigbeeBody = ["state": boolean ? "ON" : "OFF"]
        case "light.level":
            guard let number = value as? NSNumber else { return nil }
            zigbeeBody = [
                "brightness": Int(min(max(number.doubleValue, 0), 1) * 254)
            ]
        default:
            return nil
        }
        guard let payload = try? JSONSerialization.data(
            withJSONObject: zigbeeBody
        ) else {
            return nil
        }
        return (
            "\(baseTopic)/\(friendlyName)/set",
            payload,
            commandID,
            deviceID,
            capability
        )
    }

    private static func metadata(
        from device: [String: Any],
        friendlyName: String
    ) -> ZigbeeDeviceMetadata {
        let definition = device["definition"] as? [String: Any]
        let exposes = definition?["exposes"] as? [[String: Any]] ?? []
        let propertyNames = Set(
            exposes.flatMap(Self.exposedProperties)
        )
        return ZigbeeDeviceMetadata(
            deviceName: friendlyName,
            manufacturer: definition?["vendor"] as? String,
            model: definition?["model"] as? String,
            exposesTemperature: propertyNames.contains("temperature"),
            exposesLightOn: propertyNames.contains("state"),
            exposesLightLevel: propertyNames.contains("brightness")
        )
    }

    private static func exposedProperties(
        _ expose: [String: Any]
    ) -> [String] {
        var result: [String] = []
        if let property = expose["property"] as? String {
            result.append(property)
        }
        if let features = expose["features"] as? [[String: Any]] {
            result.append(contentsOf: features.flatMap(exposedProperties))
        }
        return result
    }

    private static func identifier(
        from ieeeAddress: String
    ) -> DwellIdentifier? {
        let normalized = ieeeAddress.lowercased()
            .replacingOccurrences(of: "0x", with: "")
            .filter(\.isHexDigit)
        return DwellIdentifier(rawValue: "zb-\(normalized)")
    }
}

private enum AdapterError: Error {
    case missingConfiguration
}
