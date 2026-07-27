// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct DwellRootView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Label("Home", systemImage: "house")
                Label("Rooms", systemImage: "square.grid.2x2")
                Label("Devices", systemImage: "lightbulb.2")
                Label("Automations", systemImage: "point.3.connected.trianglepath.dotted")
                Label("Activity", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                Label("Integrations", systemImage: "puzzlepiece.extension")
            }
            .navigationTitle("Dwell")
        } content: {
            ContentUnavailableView(
                "Your home will appear here",
                systemImage: "house",
                description: Text("The project foundation is ready for onboarding and daemon health.")
            )
            .navigationTitle("Home")
        } detail: {
            DwellArchitectureView()
        }
    }
}

#Preview {
    DwellRootView()
        .frame(width: 1_080, height: 720)
}
