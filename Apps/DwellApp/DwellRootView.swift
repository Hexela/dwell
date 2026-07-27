// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct DwellRootView: View {
    private enum Destination: String, CaseIterable, Identifiable {
        case home
        case devices
        case integrations

        var id: Self { self }
    }

    @State private var selection: Destination? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "house")
                    .tag(Destination.home)
                Label("Devices", systemImage: "lightbulb.2")
                    .tag(Destination.devices)
                Label("Integrations", systemImage: "puzzlepiece.extension")
                    .tag(Destination.integrations)
            }
            .navigationTitle("Dwell")
        } content: {
            switch selection {
            case .devices:
                DeviceListView()
            case .home, .integrations, nil:
                ContentUnavailableView(
                    "Your home will appear here",
                    systemImage: "house",
                    description: Text(
                        "Open Devices to inspect canonical state from the daemon."
                    )
                )
                .navigationTitle("Home")
            }
        } detail: {
            DwellArchitectureView()
        }
    }
}

#Preview {
    DwellRootView()
        .frame(width: 1_080, height: 720)
}
