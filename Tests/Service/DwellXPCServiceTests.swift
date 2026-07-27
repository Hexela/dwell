// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation
import Testing

@Suite("Dwell XPC service")
struct DwellXPCServiceTests {
    @Test("Returns health to an authorized compatible client")
    func returnsHealthSnapshot() throws {
        let response = try response(
            for: HealthSnapshotRequest(
                protocolVersion: .v1,
                role: .application
            )
        )

        #expect(response.error == nil)
        #expect(response.snapshot?.lifecycle == .starting)
    }

    @Test("Rejects incompatible protocol versions")
    func rejectsIncompatibleProtocol() throws {
        let response = try response(
            for: HealthSnapshotRequest(
                protocolVersion: .init(major: 2, minor: 0),
                role: .application
            )
        )

        #expect(response.error == .incompatibleProtocol)
        #expect(response.snapshot == nil)
    }

    @Test("Rejects roles without a health permission")
    func rejectsUnauthorizedRole() throws {
        let response = try response(
            for: HealthSnapshotRequest(
                protocolVersion: .v1,
                role: .agent
            )
        )

        #expect(response.error == .unauthorizedClient)
        #expect(response.snapshot == nil)
    }

    @Test("Rejects malformed and oversized requests")
    func rejectsMalformedRequests() throws {
        let malformed = try response(for: Data("not-json".utf8))
        let oversized = try response(for: Data(repeating: 0, count: 4_097))

        #expect(malformed.error == .malformedRequest)
        #expect(oversized.error == .malformedRequest)
    }

    private func response(
        for request: HealthSnapshotRequest
    ) throws -> HealthSnapshotResponse {
        try response(for: JSONEncoder().encode(request))
    }

    private func response(for data: Data) throws -> HealthSnapshotResponse {
        let runtime = DaemonRuntime(serviceVersion: "test")
        let service = DwellXPCService(runtime: runtime)
        var responseData: Data?
        var responseError: NSError?

        service.healthSnapshot(data) { data, error in
            responseData = data
            responseError = error
        }

        if let responseError {
            throw responseError
        }
        return try JSONDecoder().decode(
            HealthSnapshotResponse.self,
            from: #require(responseData)
        )
    }
}
