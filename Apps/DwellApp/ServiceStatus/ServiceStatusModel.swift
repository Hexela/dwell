// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import DwellIPC
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class ServiceStatusModel {
    private let service = SMAppService.daemon(
        plistName: DwellServiceConstants.launchDaemonPlistName
    )
    private let client: any DwellServiceClient

    private(set) var registrationState: ServiceRegistrationState = .notRegistered
    private(set) var snapshot: HealthSnapshot?
    private(set) var errorMessage: String?
    private(set) var isWorking = false

    init(
        client: any DwellServiceClient = XPCDwellServiceClient(role: .application)
    ) {
        self.client = client
        updateRegistrationState()
    }

    func refresh() async {
        updateRegistrationState()
        guard registrationState == .enabled else {
            snapshot = nil
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            snapshot = try await client.healthSnapshot()
            errorMessage = nil
        } catch {
            snapshot = nil
            errorMessage = "The daemon is enabled but did not answer."
        }
    }

    func register() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try service.register()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        await refresh()
    }

    func unregister() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await service.unregister()
            snapshot = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        updateRegistrationState()
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func updateRegistrationState() {
        registrationState = switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            bundledServiceIsPresent ? .notRegistered : .notFound
        @unknown default:
            .notFound
        }
    }

    /// Service Management also reports `.notFound` when no registration
    /// record exists yet, so inspect the app bundle before calling it a
    /// packaging failure.
    private var bundledServiceIsPresent: Bool {
        let contentsURL = Bundle.main.bundleURL.appending(
            path: "Contents",
            directoryHint: .isDirectory
        )
        let daemonURL = contentsURL
            .appending(path: "Library/LaunchServices/DwellDaemon")
        let propertyListURL = contentsURL.appending(
            path: "Library/LaunchDaemons/\(DwellServiceConstants.launchDaemonPlistName)"
        )

        return FileManager.default.isExecutableFile(atPath: daemonURL.path())
            && FileManager.default.fileExists(atPath: propertyListURL.path())
    }
}
