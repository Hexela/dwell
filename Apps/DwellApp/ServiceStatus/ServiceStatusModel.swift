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
    private let legacyServices = DwellServiceConstants
        .legacyLaunchDaemonPlistNames
        .map(SMAppService.daemon(plistName:))
    private let client: any DwellServiceClient
    private var didAttemptLegacyMigration = false

    private(set) var registrationState: ServiceRegistrationState = .notRegistered
    private(set) var snapshot: HealthSnapshot?
    private(set) var errorMessage: String?
    private(set) var isWorking = false

    var bundledServiceVersion: String {
        [
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "0.1.0",
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
                as? String ?? "1",
        ].joined(separator: " (") + ")"
    }

    var isServiceUpdateRecommended: Bool {
        guard registrationState == .enabled,
              let snapshot
        else {
            return false
        }
        return snapshot.serviceVersion != bundledServiceVersion
    }

    var canInstallPrivilegedService: Bool {
        CodeSigningIdentity.teamIdentifier != nil
    }

    var developmentSigningMessage: String? {
        guard canInstallPrivilegedService == false else {
            return nil
        }
        return """
            This Xcode build is signed to run locally and cannot install its \
            privileged daemon. Select an Apple Development team in Xcode, \
            rebuild, then update the service.
            """
    }

    init(
        client: any DwellServiceClient = XPCDwellServiceClient(role: .application)
    ) {
        self.client = client
        updateRegistrationState()
    }

    func refresh() async {
        await refresh(showsProgress: true)
    }

    func monitor() async {
        while Task.isCancelled == false {
            await refresh(showsProgress: false)
            do {
                try await ContinuousClock().sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }

    private func refresh(showsProgress: Bool) async {
        await migrateLegacyServiceIfNeeded()
        updateRegistrationState()
        guard registrationState == .enabled else {
            snapshot = nil
            return
        }

        if showsProgress {
            isWorking = true
        }
        defer {
            if showsProgress {
                isWorking = false
            }
        }

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

        guard canInstallPrivilegedService else {
            errorMessage = developmentSigningMessage
            return
        }

        do {
            try await unregisterLegacyServices()
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
            try await unregisterLegacyServices()
            snapshot = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        updateRegistrationState()
    }

    func updateService() async {
        isWorking = true
        defer { isWorking = false }

        guard canInstallPrivilegedService else {
            errorMessage = developmentSigningMessage
            return
        }

        do {
            try await service.unregister()
            try await unregisterLegacyServices()
            try service.register()
            errorMessage = nil
        } catch {
            errorMessage = "Dwell could not update the daemon: \(error.localizedDescription)"
        }

        updateRegistrationState()
        await refresh(showsProgress: false)
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

    private func migrateLegacyServiceIfNeeded() async {
        guard didAttemptLegacyMigration == false else {
            return
        }
        didAttemptLegacyMigration = true

        guard service.status == .notRegistered || service.status == .notFound,
              legacyServices.contains(where: {
                  $0.status == .enabled || $0.status == .requiresApproval
              })
        else {
            return
        }

        guard canInstallPrivilegedService else {
            errorMessage = developmentSigningMessage
            return
        }

        do {
            try await unregisterLegacyServices()
            try service.register()
            errorMessage = nil
        } catch {
            errorMessage = """
                Dwell could not migrate its privileged service: \
                \(error.localizedDescription)
                """
        }
    }

    private func unregisterLegacyServices() async throws {
        for legacyService in legacyServices
        where legacyService.status != .notRegistered
            && legacyService.status != .notFound
        {
            try await legacyService.unregister()
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
            .appending(path: "Resources/DwellDaemon")
        let propertyListURL = contentsURL.appending(
            path: "Library/LaunchDaemons/\(DwellServiceConstants.launchDaemonPlistName)"
        )

        return FileManager.default.isExecutableFile(atPath: daemonURL.path())
            && FileManager.default.fileExists(atPath: propertyListURL.path())
    }
}
