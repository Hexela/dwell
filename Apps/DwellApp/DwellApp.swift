// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

@main
struct DwellApp: App {
    var body: some Scene {
        WindowGroup {
            DwellRootView()
        }
        .defaultSize(width: 1_080, height: 720)
    }
}
