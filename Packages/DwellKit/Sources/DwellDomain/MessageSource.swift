// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// The canonical identity of a message producer.
public struct MessageSource: Codable, Equatable, Sendable {
    public let installationID: DwellIdentifier
    public let integrationID: DwellIdentifier

    /// Creates a canonical message source.
    ///
    /// - Parameters:
    ///   - installationID: The installation that produced the message.
    ///   - integrationID: The integration principal that produced the message.
    public init(installationID: DwellIdentifier, integrationID: DwellIdentifier) {
        self.installationID = installationID
        self.integrationID = integrationID
    }

    private enum CodingKeys: String, CodingKey {
        case installationID = "installationId"
        case integrationID = "integrationId"
    }
}
