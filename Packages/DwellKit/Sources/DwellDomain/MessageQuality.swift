// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// The producer's assessment of a canonical message's reliability.
public struct MessageQuality: Codable, Equatable, Sendable {
    /// A canonical quality classification.
    public enum Status: String, Codable, Sendable {
        case good
        case uncertain
        case stale
        case invalid
        case unavailable
    }

    public let status: Status
    public let confidence: Double?

    /// Creates a quality assessment.
    ///
    /// - Parameters:
    ///   - status: The canonical quality classification.
    ///   - confidence: A producer confidence from zero through one.
    public init(status: Status, confidence: Double? = nil) {
        self.status = status
        self.confidence = confidence
    }
}
