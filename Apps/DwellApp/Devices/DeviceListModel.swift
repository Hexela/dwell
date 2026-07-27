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
        } catch {
            errorMessage = "Dwell could not load devices from the daemon."
        }
    }

    func toggle(
        device: DeviceSnapshot,
        capability: CapabilitySnapshot,
        to value: Bool
    ) async {
        do {
            _ = try await client.perform(
                DeviceCommandRequest(
                    deviceID: device.deviceID,
                    componentID: capability.componentID,
                    capability: capability.capability,
                    value: .boolean(value),
                    idempotencyKey: UUID()
                )
            )
            errorMessage = nil
        } catch {
            errorMessage = "The light command could not be published."
        }
    }
}
