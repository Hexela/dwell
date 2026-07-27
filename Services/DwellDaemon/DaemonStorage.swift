// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellHistory
import DwellIPC
import DwellPersistence
import Foundation

/// Opens daemon-owned stores and restores their startup projections.
struct DaemonStorage: Sendable {
    let metadata: MetadataStore
    let history: HistoryStore
    let restoredStateCount: Int

    static func open(
        installationID: DwellIdentifier?,
        directory: URL,
        runtime: DaemonRuntime
    ) async throws -> DaemonStorage {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: NSNumber(value: Int16(0o750))
            ]
        )

        let metadata = try MetadataStore.open(
            at: directory.appending(path: "metadata.store")
        )
        if let installationID {
            _ = try await metadata.loadOrCreateInstallation(installationID)
        }
        runtime.update(
            ComponentHealth(
                component: .metadataStore,
                state: .healthy,
                summary: installationID == nil
                    ? "Schema 1 ready · installation not configured"
                    : "Schema 1 ready"
            )
        )

        let history = try HistoryStore(
            at: directory.appending(path: "history.sqlite")
        )
        let restoredStates = try await history.latestStates()
        let status = try await history.status()
        runtime.update(
            ComponentHealth(
                component: .historyStore,
                state: .healthy,
                summary: [
                    "Schema \(status.schemaVersion) ready",
                    "\(status.messageCount) messages",
                    "\(restoredStates.count) states restored",
                ].joined(separator: " · ")
            )
        )

        return DaemonStorage(
            metadata: metadata,
            history: history,
            restoredStateCount: restoredStates.count
        )
    }

    static func defaultDirectory(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["DWELL_DATA_DIRECTORY"],
           override.isEmpty == false
        {
            return URL(filePath: override, directoryHint: .isDirectory)
        }
        return URL(
            filePath: "/Library/Application Support/Dwell",
            directoryHint: .isDirectory
        )
    }
}
