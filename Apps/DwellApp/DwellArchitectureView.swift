// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct DwellArchitectureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var serviceStatus = ServiceStatusModel()

    var body: some View {
        Form {
            Section("Project foundation") {
                LabeledContent("Management app", value: "DwellApp")
                LabeledContent("Automation authority", value: "DwellDaemon")
                LabeledContent("Diagnostics", value: "dwellctl")
                LabeledContent("Shared contracts", value: "DwellKit")
            }

            Section("Current status") {
                Label(
                    "Canonical MQTT schemas and typed decoding are available",
                    systemImage: "checkmark.circle.fill"
                )
                    .foregroundStyle(.green)
                Label(
                    "XPC health is available after daemon registration",
                    systemImage: "network"
                )
            }

            ServiceStatusView(model: serviceStatus)
        }
        .formStyle(.grouped)
        .navigationTitle("Architecture")
        .task(id: scenePhase) {
            await refreshServiceStatusWhenActive()
        }
    }

    private func refreshServiceStatusWhenActive() async {
        guard scenePhase == .active else {
            return
        }

        await serviceStatus.monitor()
    }
}

#Preview {
    DwellArchitectureView()
        .frame(width: 480, height: 560)
}
