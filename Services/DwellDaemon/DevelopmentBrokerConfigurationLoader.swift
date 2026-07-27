// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellMQTT
import Darwin
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

        let executableDirectory = resolvedExecutableDirectory()
        urls.append(
            executableDirectory.appending(
                path: "development-broker.json"
            )
        )
        return urls
    }

    private static func resolvedExecutableDirectory() -> URL {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        let result = buffer.withUnsafeMutableBufferPointer {
            _NSGetExecutablePath($0.baseAddress, &size)
        }
        guard result == 0 else {
            return URL(filePath: CommandLine.arguments[0])
                .standardizedFileURL
                .deletingLastPathComponent()
        }
        let path = String(
            decoding: buffer.prefix { $0 != 0 }.map {
                UInt8(bitPattern: $0)
            },
            as: UTF8.self
        )
        return URL(filePath: path)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
    }
}
