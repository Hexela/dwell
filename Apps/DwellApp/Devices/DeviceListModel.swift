// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellIPC
import Foundation
import Observation

@MainActor
@Observable
final class DeviceListModel {
    private let client: any DwellServiceClient

    private(set) var devices: [DeviceSnapshot] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    init(
        client: any DwellServiceClient = XPCDwellServiceClient(role: .application)
    ) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await client.deviceSnapshot().devices
            errorMessage = nil
        } catch ServiceRequestError.malformedResponse {
            errorMessage = """
                The registered daemon returned an older device format. \
                Update the service from Home.
                """
        } catch {
            errorMessage = "Dwell could not load devices from the daemon."
        }
    }

    func monitor() async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: .seconds(2))
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    func setValue(
        device: DeviceSnapshot,
        capability: CapabilitySnapshot,
        to value: CapabilitySnapshot.Value
    ) async {
        do {
            _ = try await client.perform(
                DeviceCommandRequest(
                    deviceID: device.deviceID,
                    componentID: capability.componentID,
                    capability: capability.capability,
                    value: value,
                    idempotencyKey: UUID()
                )
            )
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = "The light command could not be published."
        }
    }
}
