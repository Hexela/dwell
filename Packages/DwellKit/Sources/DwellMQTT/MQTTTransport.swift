// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation

/// A transport-level MQTT publication.
public struct MQTTMessage: Equatable, Sendable {
    public let topic: String
    public let payload: Data
    public let qualityOfService: Int
    public let isRetained: Bool
    public let isDuplicate: Bool

    /// Creates an MQTT publication value.
    public init(
        topic: String,
        payload: Data,
        qualityOfService: Int,
        isRetained: Bool,
        isDuplicate: Bool
    ) {
        self.topic = topic
        self.payload = payload
        self.qualityOfService = qualityOfService
        self.isRetained = isRetained
        self.isDuplicate = isDuplicate
    }
}

/// A connected MQTT transport owned by a broker session actor.
public protocol MQTTTransport: Sendable {
    /// Connects and establishes a persistent MQTT session.
    func connect() async throws

    /// Subscribes at QoS 1 to a topic filter.
    func subscribe(to topicFilter: String) async throws

    /// Publishes a message at QoS 1.
    func publish(_ payload: Data, to topic: String, retain: Bool) async throws

    /// Returns publications until the connection closes.
    func incomingMessages() async -> AsyncThrowingStream<MQTTMessage, any Error>

    /// Disconnects and releases transport resources.
    func disconnect() async
}

/// Creates a fresh transport for each connection attempt.
public protocol MQTTTransportFactory: Sendable {
    /// Creates a transport configured for the supplied broker.
    func makeTransport(
        configuration: BrokerConfiguration,
        lastWillPayload: Data
    ) async throws -> any MQTTTransport
}
