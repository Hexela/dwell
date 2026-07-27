// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct ServiceStatusActions: View {
    let model: ServiceStatusModel

    var body: some View {
        HStack {
            switch model.registrationState {
            case .notRegistered:
                Button(
                    "Register Daemon",
                    systemImage: "gear.badge",
                    action: register
                )
            case .requiresApproval:
                Button(
                    "Open Login Items Settings",
                    systemImage: "person.badge.key",
                    action: model.openApprovalSettings
                )
                Button("Unregister", role: .destructive, action: unregister)
            case .enabled:
                Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                Button("Unregister", role: .destructive, action: unregister)
            case .notFound:
                Text("Build Dwell again to restore the embedded daemon.")
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(model.isWorking)
    }

    private func register() {
        Task {
            await model.register()
        }
    }

    private func unregister() {
        Task {
            await model.unregister()
        }
    }

    private func refresh() {
        Task {
            await model.refresh()
        }
    }
}
