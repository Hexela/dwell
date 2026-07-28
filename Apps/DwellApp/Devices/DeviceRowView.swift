// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import SwiftUI

struct DeviceRowView: View {
    let device: DeviceSnapshot
    let setValue: (CapabilitySnapshot, CapabilitySnapshot.Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(device.displayName, systemImage: "sensor")
                    .font(.headline)
                Spacer()
                Text(device.availability.capitalized)
                    .foregroundStyle(
                        device.availability == "online" ? .green : .secondary
                    )
            }

            if let detail = deviceDetail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(device.capabilities) { capability in
                CapabilityControlView(
                    capability: capability,
                    command: latestCommand(for: capability),
                    setValue: { setValue(capability, $0) }
                )
            }
        }
        .padding(.vertical, 5)
    }

    private var deviceDetail: String? {
        [device.manufacturer, device.model]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    private func latestCommand(
        for capability: CapabilitySnapshot
    ) -> DeviceCommandSnapshot? {
        device.commands
            .filter {
                $0.componentID == capability.componentID
                    && $0.capability == capability.capability
            }
            .max { $0.requestedAt < $1.requestedAt }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
