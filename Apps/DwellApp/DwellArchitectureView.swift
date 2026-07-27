// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct DwellArchitectureView: View {
    var body: some View {
        Form {
            Section("Project foundation") {
                LabeledContent("Management app", value: "DwellApp")
                LabeledContent("Automation authority", value: "DwellDaemon")
                LabeledContent("Diagnostics", value: "dwellctl")
                LabeledContent("Shared contracts", value: "DwellKit")
            }

            Section("Current status") {
                Label("Canonical MQTT topic contract is available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("Daemon and client communication is not yet connected", systemImage: "circle.dotted")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Architecture")
    }
}

#Preview {
    DwellArchitectureView()
        .frame(width: 480, height: 560)
}
