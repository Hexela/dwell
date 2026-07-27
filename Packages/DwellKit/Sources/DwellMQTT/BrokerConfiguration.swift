// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

/// Configuration for one daemon-owned MQTT session.
public struct BrokerConfiguration: Codable, Equatable, Sendable {
    /// The MQTT protocol revision used for the session.
    public enum ProtocolVersion: String, Codable, Sendable {
        case v3_1_1 = "3.1.1"
        case v5 = "5.0"
    }

    public let host: String
    public let port: Int
    public let clientIdentifier: String
    public let installationIdentifier: String
    public let protocolVersion: ProtocolVersion
    public let usesTLS: Bool
    public let username: String?
    public let password: String?
    public let statusTopicOverride: String?

    /// Creates a validated broker configuration.
    public init(
        host: String,
        port: Int,
        clientIdentifier: String,
        installationIdentifier: String,
        protocolVersion: ProtocolVersion = .v5,
        usesTLS: Bool = true,
        username: String? = nil,
        password: String? = nil,
        statusTopicOverride: String? = nil
    ) {
        precondition(host.isEmpty == false)
        precondition((1...65_535).contains(port))
        precondition(clientIdentifier.isEmpty == false)
        precondition(installationIdentifier.isEmpty == false)
        self.host = host
        self.port = port
        self.clientIdentifier = clientIdentifier
        self.installationIdentifier = installationIdentifier
        self.protocolVersion = protocolVersion
        self.usesTLS = usesTLS
        self.username = username
        self.password = password
        self.statusTopicOverride = statusTopicOverride
    }

    /// The canonical topic filter owned by this installation.
    public var canonicalTopicFilter: String {
        "dwell/v1/i/\(installationIdentifier)/#"
    }

    /// The retained daemon availability topic.
    public var statusTopic: String {
        statusTopicOverride
            ?? "dwell/v1/i/\(installationIdentifier)/system/status"
    }
}
