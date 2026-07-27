// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellIPC
import Darwin
import Foundation

/// Starts the bundled first-party Zigbee adapter and reports its lifecycle.
final class AdapterSupervisor: @unchecked Sendable {
    private let runtime: DaemonRuntime
    private var process: Process?

    init(runtime: DaemonRuntime) {
        self.runtime = runtime
    }

    func startIfAvailable() {
        let executable = resolvedExecutableDirectory()
            .appending(path: "DwellZigbeeAdapter")
        guard FileManager.default.isExecutableFile(atPath: executable.path())
        else {
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: .notConfigured,
                    summary: "Adapter is not bundled"
                )
            )
            return
        }

        let process = Process()
        process.executableURL = executable
        process.environment = ProcessInfo.processInfo.environment
        process.terminationHandler = { [runtime] process in
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: .unavailable,
                    summary: "Stopped with status \(process.terminationStatus)"
                )
            )
        }
        do {
            try process.run()
            self.process = process
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: .healthy,
                    summary: "Running"
                )
            )
        } catch {
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: .unavailable,
                    summary: "Could not start"
                )
            )
        }
    }

    private func resolvedExecutableDirectory() -> URL {
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
