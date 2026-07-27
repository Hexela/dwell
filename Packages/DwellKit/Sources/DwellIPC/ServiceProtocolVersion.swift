// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// A version of Dwell's local service protocol.
public struct ServiceProtocolVersion: Codable, Comparable, Hashable, Sendable {
    /// The first supported service protocol version.
    public static let v1 = ServiceProtocolVersion(major: 1, minor: 0)

    public let major: Int
    public let minor: Int

    /// Creates a service protocol version.
    ///
    /// - Parameters:
    ///   - major: The breaking compatibility version.
    ///   - minor: The additive compatibility version.
    public init(major: Int, minor: Int) {
        precondition(major >= 0 && minor >= 0)
        self.major = major
        self.minor = minor
    }

    /// Returns whether this version can communicate with another version.
    ///
    /// - Parameter other: The peer's protocol version.
    public func isCompatible(with other: Self) -> Bool {
        major == other.major
    }

    /// Compares service protocol versions in semantic order.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}
