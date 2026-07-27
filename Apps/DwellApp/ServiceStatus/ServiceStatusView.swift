// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import SwiftUI

struct ServiceStatusView: View {
    @Bindable var model: ServiceStatusModel

    var body: some View {
        Section("Automation authority") {
            Label(
                model.registrationState.title,
                systemImage: model.registrationState.systemImage
            )

            if let snapshot = model.snapshot {
                LabeledContent("Lifecycle", value: snapshot.lifecycle.title)
                LabeledContent("Version", value: snapshot.serviceVersion)
                LabeledContent(
                    "Uptime",
                    value: Duration.seconds(snapshot.uptimeSeconds).formatted()
                )

                ForEach(snapshot.components) { component in
                    LabeledContent(
                        component.component.title,
                        value: component.state.title
                    )
                }
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            ServiceStatusActions(model: model)
        }
    }
}

private extension ServiceLifecycleState {
    var title: String {
        switch self {
        case .starting: "Starting"
        case .ready: "Ready"
        case .degraded: "Degraded"
        case .safeMode: "Safe mode"
        case .stopping: "Stopping"
        }
    }
}

private extension ServiceComponent {
    var title: String {
        switch self {
        case .broker: "MQTT broker"
        case .metadataStore: "Metadata store"
        case .historyStore: "History store"
        case .scheduler: "Scheduler"
        }
    }
}

private extension ComponentHealthState {
    var title: String {
        switch self {
        case .healthy: "Healthy"
        case .degraded: "Degraded"
        case .unavailable: "Unavailable"
        case .notConfigured: "Not configured"
        }
    }
}
