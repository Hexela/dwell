// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import DwellRegistry
import Foundation

/// Handles the daemon's versioned read-only XPC wire operation.
final class DwellXPCService: NSObject, DwellXPCWireService, @unchecked Sendable {
    private static let maximumRequestSize = 4 * 1_024

    private let runtime: DaemonRuntime
    private let registry: DeviceRegistry
    private let commandDispatcher: DeviceCommandDispatcher

    init(
        runtime: DaemonRuntime,
        registry: DeviceRegistry = DeviceRegistry(),
        commandDispatcher: DeviceCommandDispatcher = DeviceCommandDispatcher()
    ) {
        self.runtime = runtime
        self.registry = registry
        self.commandDispatcher = commandDispatcher
    }

    func performDeviceCommand(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        guard requestData.count <= Self.maximumRequestSize,
              let request = try? JSONDecoder().decode(
                  DeviceCommandWireRequest.self,
                  from: requestData
              ),
              ServiceProtocolVersion.v1.isCompatible(
                  with: request.protocolVersion
              ),
              request.role == .application
        else {
            sendCommand(.failure(.malformedRequest), using: reply)
            return
        }
        let replyBox = XPCDataReply(reply)
        Task {
            do {
                let acceptance = try await commandDispatcher.submit(
                    request.command
                )
                sendCommand(.success(acceptance), using: replyBox.call)
            } catch {
                sendCommand(.failure(.serviceUnavailable), using: replyBox.call)
            }
        }
    }

    func deviceSnapshot(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        guard requestData.count <= Self.maximumRequestSize,
              let request = try? JSONDecoder().decode(
                  DeviceSnapshotRequest.self,
                  from: requestData
              )
        else {
            sendDevice(.failure(.malformedRequest), using: reply)
            return
        }
        guard ServiceProtocolVersion.v1.isCompatible(
            with: request.protocolVersion
        ) else {
            sendDevice(.failure(.incompatibleProtocol), using: reply)
            return
        }
        guard request.role == .application || request.role == .commandLineTool else {
            sendDevice(.failure(.unauthorizedClient), using: reply)
            return
        }

        let replyBox = XPCDataReply(reply)
        Task {
            let snapshot = await registry.snapshot()
            sendDevice(.success(snapshot), using: replyBox.call)
        }
    }

    func healthSnapshot(
        _ requestData: Data,
        withReply reply: @escaping (Data?, NSError?) -> Void
    ) {
        guard requestData.count <= Self.maximumRequestSize,
              let request = try? JSONDecoder().decode(
                  HealthSnapshotRequest.self,
                  from: requestData
              )
        else {
            send(.failure(.malformedRequest), using: reply)
            return
        }

        guard ServiceProtocolVersion.v1.isCompatible(
            with: request.protocolVersion
        ) else {
            send(.failure(.incompatibleProtocol), using: reply)
            return
        }

        guard request.role == .application || request.role == .commandLineTool else {
            send(.failure(.unauthorizedClient), using: reply)
            return
        }

        send(.success(runtime.snapshot()), using: reply)
    }

    private func send(
        _ response: HealthSnapshotResponse,
        using reply: (Data?, NSError?) -> Void
    ) {
        do {
            reply(try JSONEncoder().encode(response), nil)
        } catch {
            reply(
                nil,
                NSError(
                    domain: "com.hexela.dwell.ipc",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not encode the service response."
                    ]
                )
            )
        }
    }

    private func sendDevice(
        _ response: DeviceSnapshotResponse,
        using reply: (Data?, NSError?) -> Void
    ) {
        do {
            reply(try JSONEncoder().encode(response), nil)
        } catch {
            reply(nil, NSError(domain: "com.hexela.dwell.ipc", code: 2))
        }
    }

    private func sendCommand(
        _ response: DeviceCommandWireResponse,
        using reply: (Data?, NSError?) -> Void
    ) {
        do {
            reply(try JSONEncoder().encode(response), nil)
        } catch {
            reply(nil, NSError(domain: "com.hexela.dwell.ipc", code: 3))
        }
    }
}

private final class XPCDataReply: @unchecked Sendable {
    let call: (Data?, NSError?) -> Void

    init(_ call: @escaping (Data?, NSError?) -> Void) {
        self.call = call
    }
}
