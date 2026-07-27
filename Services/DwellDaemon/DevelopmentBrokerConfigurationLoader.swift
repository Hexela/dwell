// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellMQTT
import Foundation

/// Loads ignored development broker configuration without logging secrets.
enum DevelopmentBrokerConfigurationLoader {
    static func load() throws -> BrokerConfiguration? {
        for url in candidateURLs where FileManager.default.fileExists(atPath: url.path()) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BrokerConfiguration.self, from: data)
        }
        return nil
    }

    private static var candidateURLs: [URL] {
        var urls: [URL] = []
        if let configuredPath = ProcessInfo.processInfo.environment[
            "DWELL_BROKER_CONFIGURATION"
        ] {
            urls.append(URL(filePath: configuredPath))
        }

        var executableURL = URL(filePath: CommandLine.arguments[0])
            .standardizedFileURL
        executableURL.deleteLastPathComponent()
        executableURL.deleteLastPathComponent()
        executableURL.deleteLastPathComponent()
        urls.append(
            executableURL.appending(
                path: "Resources/development-broker.json"
            )
        )
        return urls
    }
}
