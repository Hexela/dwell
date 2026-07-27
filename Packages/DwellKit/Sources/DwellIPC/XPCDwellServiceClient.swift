// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@preconcurrency import Foundation
import DwellDomain
import Synchronization

/// A client for the privileged local Dwell Mach service.
public actor XPCDwellServiceClient: DwellServiceClient {
    private let role: ClientRole

    /// Creates an XPC service client for a signed local role.
    ///
    /// - Parameter role: The role declared during protocol negotiation.
    public init(role: ClientRole) {
        self.role = role
    }

    /// Requests the daemon's current health snapshot.
    public func healthSnapshot() async throws -> HealthSnapshot {
        try await request(
            HealthSnapshotRequest(protocolVersion: .v1, role: role),
            operation: { service, data, reply in
                service.healthSnapshot(data, withReply: reply)
            },
            decode: HealthSnapshotResponse.self
        ) { response in
            response.snapshot
        }
    }

    public func deviceSnapshot() async throws -> DeviceCollectionSnapshot {
        try await request(
            DeviceSnapshotRequest(protocolVersion: .v1, role: role),
            operation: { service, data, reply in
                service.deviceSnapshot(data, withReply: reply)
            },
            decode: DeviceSnapshotResponse.self
        ) { response in
            response.snapshot
        }
    }

    public func perform(
        _ command: DeviceCommandRequest
    ) async throws -> DeviceCommandAcceptance {
        try await request(
            DeviceCommandWireRequest(
                protocolVersion: .v1,
                role: role,
                command: command
            ),
            operation: { service, data, reply in
                service.performDeviceCommand(data, withReply: reply)
            },
            decode: DeviceCommandWireResponse.self
        ) { response in
            response.acceptance
        }
    }

    private func request<Request: Encodable, Response: Decodable, Value: Sendable>(
        _ request: Request,
        operation: @escaping (
            DwellXPCWireService,
            Data,
            @escaping (Data?, NSError?) -> Void
        ) -> Void,
        decode: Response.Type,
        value: @escaping (Response) -> Value?
    ) async throws -> Value {
        let connection = NSXPCConnection(
            machServiceName: DwellServiceConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: DwellXPCWireService.self
        )
        connection.activate()

        defer {
            connection.invalidate()
        }

        let requestData = try JSONEncoder().encode(request)

        return try await withCheckedThrowingContinuation { continuation in
            let gate = XPCReplyGate(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { _ in
                gate.resume(throwing: ServiceRequestError.serviceUnavailable)
            }

            guard let service = proxy as? DwellXPCWireService else {
                gate.resume(throwing: ServiceRequestError.serviceUnavailable)
                return
            }

            operation(service, requestData) { data, error in
                guard error == nil, let data else {
                    gate.resume(throwing: ServiceRequestError.serviceUnavailable)
                    return
                }

                do {
                    let response = try JSONDecoder().decode(decode, from: data)
                    if let result = value(response) {
                        gate.resume(returning: result)
                    } else if let error = (response as? HealthSnapshotResponse)?.error
                        ?? (response as? DeviceSnapshotResponse)?.error
                        ?? (response as? DeviceCommandWireResponse)?.error
                    {
                        gate.resume(throwing: error)
                    } else {
                        gate.resume(throwing: ServiceRequestError.malformedResponse)
                    }
                } catch {
                    gate.resume(throwing: ServiceRequestError.malformedResponse)
                }
            }
        }
    }
}

private final class XPCReplyGate<Value: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<Value, any Error>?>

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = Mutex(continuation)
    }

    func resume(returning value: sending Value) {
        takeContinuation()?.resume(returning: value)
    }

    func resume(throwing error: any Error) {
        takeContinuation()?.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<Value, any Error>? {
        continuation.withLock { continuation in
            let result = continuation
            continuation = nil
            return result
        }
    }
}
