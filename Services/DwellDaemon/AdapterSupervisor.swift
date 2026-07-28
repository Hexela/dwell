// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellIPC
import Darwin
import Foundation
import Synchronization

struct AdapterRestartPolicy: Equatable, Sendable {
    let maximumConsecutiveRestarts: Int
    let initialDelay: Duration
    let maximumDelay: Duration

    static let `default` = Self(
        maximumConsecutiveRestarts: 5,
        initialDelay: .seconds(1),
        maximumDelay: .seconds(30)
    )

    func delay(after failureCount: Int) -> Duration? {
        guard failureCount <= maximumConsecutiveRestarts else {
            return nil
        }
        let multiplier = 1 << max(0, min(failureCount - 1, 20))
        return min(initialDelay * multiplier, maximumDelay)
    }
}

/// Supervises the bundled adapter with bounded restart and explicit shutdown.
final class AdapterSupervisor: @unchecked Sendable {
    private struct State {
        var process: Process?
        var restartTask: Task<Void, Never>?
        var failureCount = 0
        var isStopping = false
    }

    private let runtime: DaemonRuntime
    private let policy: AdapterRestartPolicy
    private let state = Mutex(State())

    init(
        runtime: DaemonRuntime,
        policy: AdapterRestartPolicy = .default
    ) {
        self.runtime = runtime
        self.policy = policy
    }

    func startIfAvailable() {
        state.withLock {
            $0.isStopping = false
        }
        launch()
    }

    func stop() {
        let process = state.withLock { state -> Process? in
            state.isStopping = true
            state.restartTask?.cancel()
            state.restartTask = nil
            let process = state.process
            state.process = nil
            return process
        }
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func launch() {
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

        let shouldLaunch = state.withLock {
            !$0.isStopping && $0.process == nil
        }
        guard shouldLaunch else {
            return
        }

        let process = Process()
        process.executableURL = executable
        process.environment = ProcessInfo.processInfo.environment
        process.terminationHandler = { [weak self] process in
            self?.processTerminated(status: process.terminationStatus)
        }
        do {
            try process.run()
            state.withLock {
                $0.process = process
            }
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: .healthy,
                    summary: "Running"
                )
            )
        } catch {
            processTerminated(status: -1)
        }
    }

    private func processTerminated(status: Int32) {
        let restart = state.withLock { state -> (Int, Duration)? in
            state.process = nil
            guard !state.isStopping else {
                return nil
            }
            state.failureCount += 1
            guard let delay = policy.delay(after: state.failureCount) else {
                return nil
            }
            return (state.failureCount, delay)
        }

        guard let (attempt, delay) = restart else {
            let isStopping = state.withLock { $0.isStopping }
            runtime.update(
                ComponentHealth(
                    component: .zigbeeAdapter,
                    state: isStopping ? .notConfigured : .unavailable,
                    summary: isStopping
                        ? "Stopped"
                        : "Crash loop detected; automatic restart stopped"
                )
            )
            return
        }

        runtime.update(
            ComponentHealth(
                component: .zigbeeAdapter,
                state: .degraded,
                summary: "Restarting after exit \(status) (attempt \(attempt))"
            )
        )
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else {
                    return
                }
                self?.launch()
            } catch {
                return
            }
        }
        state.withLock {
            $0.restartTask?.cancel()
            $0.restartTask = task
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
