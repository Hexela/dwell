// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation

/// Handles the daemon's versioned read-only XPC wire operation.
final class DwellXPCService: NSObject, DwellXPCWireService {
    private static let maximumRequestSize = 4 * 1_024

    private let runtime: DaemonRuntime

    init(runtime: DaemonRuntime) {
        self.runtime = runtime
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
}
