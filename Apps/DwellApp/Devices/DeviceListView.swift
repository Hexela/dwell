// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

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
                    DeviceRowView(device: device) { capability, value in
                        Task {
                            await model.setValue(
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
        .safeAreaInset(edge: .bottom) {
            if model.devices.isEmpty == false,
               let errorMessage = model.errorMessage
            {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await model.refresh()
                }
            }
            .disabled(model.isLoading)
        }
        .task {
            await model.monitor()
        }
    }
}
