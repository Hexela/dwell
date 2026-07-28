// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellDomain

/// A canonical schema family supported by the v1 decoder.
public enum CanonicalSchema: String, CaseIterable, Sendable {
    case deviceMetadata = "io.dwell.device-metadata"
    case quantityState = "io.dwell.state.quantity"
    case booleanState = "io.dwell.state.boolean"
    case levelState = "io.dwell.state.level"
    case enumerationState = "io.dwell.state.enum"
    case availability = "io.dwell.availability"
    case command = "io.dwell.command"
    case commandAcknowledgement = "io.dwell.command-ack"

    /// Returns the supported schema family for an identifier.
    ///
    /// Compatible minor versions are accepted within major version 1.
    ///
    /// - Parameter identifier: The schema identifier to resolve.
    public init?(identifier: SchemaID) {
        guard identifier.majorVersion == 1,
              let schema = Self(rawValue: identifier.name)
        else {
            return nil
        }

        self = schema
    }

    /// The checked-in JSON Schema filename for this family.
    public var filename: String {
        switch self {
        case .deviceMetadata:
            "device-metadata.schema.json"
        case .quantityState:
            "state-quantity.schema.json"
        case .booleanState:
            "state-boolean.schema.json"
        case .levelState:
            "state-level.schema.json"
        case .enumerationState:
            "state-enum.schema.json"
        case .availability:
            "availability.schema.json"
        case .command:
            "command.schema.json"
        case .commandAcknowledgement:
            "command-ack.schema.json"
        }
    }
}
