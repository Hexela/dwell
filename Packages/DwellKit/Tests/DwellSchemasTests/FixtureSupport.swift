// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing

enum FixtureSupport {
    static func mqttPayload(
        named name: String,
        validity: String,
        sourceFile: StaticString = #filePath
    ) throws -> Data {
        try Data(
            contentsOf: repositoryRoot(sourceFile: sourceFile)
                .appending(path: "Tests/Fixtures/MQTT/v1/\(validity)/\(name).json")
        )
    }

    static func schemaDocument(
        named name: String,
        sourceFile: StaticString = #filePath
    ) throws -> Data {
        try Data(
            contentsOf: repositoryRoot(sourceFile: sourceFile)
                .appending(path: "Schemas/MQTT/v1/\(name)")
        )
    }

    static func schemaURL(
        named name: String,
        sourceFile: StaticString = #filePath
    ) -> URL {
        repositoryRoot(sourceFile: sourceFile)
            .appending(path: "Schemas/MQTT/v1/\(name)")
    }

    private static func repositoryRoot(sourceFile: StaticString) -> URL {
        var url = URL(filePath: "\(sourceFile)")
        for _ in 0..<5 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
