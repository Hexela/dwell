// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// An opaque identifier used by Dwell protocol and domain objects.
///
/// Identifiers contain 1 through 64 lowercase ASCII letters, digits, or
/// hyphens, and must begin with a letter or digit.
public struct DwellIdentifier: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    /// Creates an identifier when `rawValue` satisfies the Dwell identifier
    /// grammar.
    ///
    /// - Parameter rawValue: The protocol representation of the identifier.
    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else {
            return nil
        }

        self.rawValue = rawValue
    }

    private static func isValid(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count),
              let first = value.utf8.first,
              isLowercaseLetterOrDigit(first)
        else {
            return false
        }

        return value.utf8.allSatisfy {
            isLowercaseLetterOrDigit($0) || $0 == 45
        }
    }

    private static func isLowercaseLetterOrDigit(_ character: UInt8) -> Bool {
        switch character {
        case 48...57, 97...122:
            true
        default:
            false
        }
    }
}
