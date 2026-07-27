// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import SwiftUI

struct DeviceListView: View {
    @State private var model = DeviceListModel()

    var body: some View {
        Group {
            if model.devices.isEmpty {
                ContentUnavailableView(
                    "No devices yet",
                    systemImage: "sensor",
                    description: Text(
                        model.errorMessage
                            ?? "Canonical device state will appear here when the broker receives it."
                    )
                )
            } else {
                List(model.devices) { device in
                    DeviceRow(device: device) { capability, value in
                        Task {
                            await model.toggle(
                                device: device,
                                capability: capability,
                                to: value
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await model.refresh()
                }
            }
            .disabled(model.isLoading)
        }
        .task {
            await model.refresh()
        }
    }
}

private struct DeviceRow: View {
    let device: DeviceSnapshot
    let setBoolean: (CapabilitySnapshot, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(device.displayName, systemImage: "sensor")
                    .font(.headline)
                Spacer()
                Text(device.availability.capitalized)
                    .foregroundStyle(device.availability == "online" ? .green : .secondary)
            }

            ForEach(device.capabilities) { capability in
                LabeledContent(capability.capability) {
                    CapabilityValueView(
                        capability: capability,
                        setBoolean: setBoolean
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CapabilityValueView: View {
    let capability: CapabilitySnapshot
    let setBoolean: (CapabilitySnapshot, Bool) -> Void

    var body: some View {
        HStack(spacing: 6) {
            switch capability.value {
            case let .number(value, unit):
                Text(value, format: .number.precision(.fractionLength(0...2)))
                if let unit {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            case let .boolean(value):
                Button(value ? "Turn Off" : "Turn On") {
                    setBoolean(capability, !value)
                }
                .disabled(capability.capability != "light.on")
            case let .text(value):
                Text(value)
            }

            if capability.isStale {
                Label("Stale", systemImage: "clock.badge.exclamationmark")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.orange)
            }
        }
    }
}
