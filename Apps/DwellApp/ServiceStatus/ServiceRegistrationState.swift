// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// The user-facing registration state of the Dwell LaunchDaemon.
enum ServiceRegistrationState {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    var title: String {
        switch self {
        case .notRegistered:
            "Not registered"
        case .enabled:
            "Enabled"
        case .requiresApproval:
            "Awaiting administrator approval"
        case .notFound:
            "Daemon missing from this app"
        }
    }

    var systemImage: String {
        switch self {
        case .enabled:
            "checkmark.circle.fill"
        case .requiresApproval:
            "person.badge.key.fill"
        case .notRegistered:
            "circle"
        case .notFound:
            "exclamationmark.triangle.fill"
        }
    }
}
