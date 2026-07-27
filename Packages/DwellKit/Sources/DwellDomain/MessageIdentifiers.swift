// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// An identifier that deduplicates a canonical message.
public struct MessageID: Codable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    /// Creates a message identifier when its value satisfies the Dwell
    /// identifier grammar.
    ///
    /// - Parameter rawValue: The protocol representation of the identifier.
    public init?(rawValue: String) {
        guard DwellIdentifier(rawValue: rawValue) != nil else {
            return nil
        }

        self.rawValue = rawValue
    }

    /// Decodes a validated message identifier from a single string value.
    ///
    /// - Parameter decoder: The decoder containing the protocol value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let identifier = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Dwell message identifier."
            )
        }

        self = identifier
    }

    /// Encodes the message identifier as a single string value.
    ///
    /// - Parameter encoder: The encoder receiving the protocol value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// An identifier that connects messages belonging to the same operation.
public struct CorrelationID: Codable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    /// Creates a correlation identifier when its value satisfies the Dwell
    /// identifier grammar.
    ///
    /// - Parameter rawValue: The protocol representation of the identifier.
    public init?(rawValue: String) {
        guard DwellIdentifier(rawValue: rawValue) != nil else {
            return nil
        }

        self.rawValue = rawValue
    }

    /// Decodes a validated correlation identifier from a single string value.
    ///
    /// - Parameter decoder: The decoder containing the protocol value.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let identifier = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Dwell correlation identifier."
            )
        }

        self = identifier
    }

    /// Encodes the correlation identifier as a single string value.
    ///
    /// - Parameter encoder: The encoder receiving the protocol value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
