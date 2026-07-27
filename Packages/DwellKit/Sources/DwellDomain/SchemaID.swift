// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// The name and semantic version of a canonical payload schema.
public struct SchemaID: Hashable, Sendable {
    public let name: String
    public let majorVersion: Int
    public let minorVersion: Int

    /// Creates a schema identifier from its protocol representation.
    ///
    /// The accepted form is `<reverse-DNS-name>/<major>.<minor>`.
    ///
    /// - Parameter rawValue: The complete schema identifier.
    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }

        let version = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard version.count == 2,
              let majorVersion = Int(version[0]),
              let minorVersion = Int(version[1]),
              majorVersion >= 0,
              minorVersion >= 0,
              Self.isValidName(String(parts[0]))
        else {
            return nil
        }

        name = String(parts[0])
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
    }

    /// The protocol representation of the schema identifier.
    public var rawValue: String {
        "\(name)/\(majorVersion).\(minorVersion)"
    }

    private static func isValidName(_ name: String) -> Bool {
        let components = name.split(separator: ".", omittingEmptySubsequences: false)
        return components.count >= 3
            && components.allSatisfy {
                DwellIdentifier(rawValue: String($0)) != nil
            }
    }
}

extension SchemaID: Codable {
    /// Decodes a schema identifier from a single string value.
    ///
    /// - Parameter decoder: The decoder containing the protocol value.
    /// - Throws: `DecodingError.dataCorrupted` for malformed identifiers.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let identifier = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Dwell schema identifier."
            )
        }

        self = identifier
    }

    /// Encodes the schema identifier as a single string value.
    ///
    /// - Parameter encoder: The encoder receiving the protocol value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
