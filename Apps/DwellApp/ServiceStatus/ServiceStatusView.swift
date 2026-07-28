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
                if model.isServiceUpdateRecommended {
                    Label(
                        "This app contains daemon \(model.bundledServiceVersion). Update the service to use it.",
                        systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                    )
                    .foregroundStyle(.orange)
                }
                LabeledContent(
                    "Uptime",
                    value: Duration.seconds(snapshot.uptimeSeconds).formatted()
                )

                ForEach(snapshot.components) { component in
                    LabeledContent(
                        component.component.title,
                        value: "\(component.state.title) — \(component.summary)"
                    )
                }
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            if let signingMessage = model.developmentSigningMessage {
                Label(signingMessage, systemImage: "signature")
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
        case .zigbeeAdapter: "Zigbee2MQTT adapter"
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
