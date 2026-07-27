// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import Foundation
import SwiftData

/// A Sendable snapshot of installation metadata.
public struct InstallationRecord: Equatable, Sendable {
    public let installationID: DwellIdentifier
    public let createdAt: Date

    public init(installationID: DwellIdentifier, createdAt: Date) {
        self.installationID = installationID
        self.createdAt = createdAt
    }
}

/// Serializes access to daemon-owned SwiftData metadata.
@ModelActor
public actor MetadataStore {
    /// Creates the production model container at a daemon-owned URL.
    public static func open(at url: URL) throws -> MetadataStore {
        let schema = Schema(versionedSchema: MetadataSchemaV1.self)
        let configuration = ModelConfiguration(
            "DwellMetadata",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: MetadataMigrationPlan.self,
            configurations: configuration
        )
        return MetadataStore(modelContainer: container)
    }

    /// Creates an isolated in-memory metadata store for tests.
    public static func inMemory() throws -> MetadataStore {
        let schema = Schema(versionedSchema: MetadataSchemaV1.self)
        let configuration = ModelConfiguration(
            "DwellMetadataTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: MetadataMigrationPlan.self,
            configurations: configuration
        )
        return MetadataStore(modelContainer: container)
    }

    /// Loads the installation identity or creates it exactly once.
    public func loadOrCreateInstallation(
        _ installationID: DwellIdentifier,
        now: Date = Date()
    ) throws -> InstallationRecord {
        var descriptor = FetchDescriptor<InstallationMetadata>(
            predicate: #Predicate { $0.singletonKey == "installation" }
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            guard existing.installationID == installationID.rawValue else {
                throw MetadataStoreError.installationMismatch
            }
            return InstallationRecord(
                installationID: installationID,
                createdAt: existing.createdAt
            )
        }

        let metadata = InstallationMetadata(
            installationID: installationID.rawValue,
            createdAt: now
        )
        modelContext.insert(metadata)
        try modelContext.save()
        return InstallationRecord(
            installationID: installationID,
            createdAt: now
        )
    }

    /// Returns the configured installation without creating one.
    public func installation() throws -> InstallationRecord? {
        var descriptor = FetchDescriptor<InstallationMetadata>(
            predicate: #Predicate { $0.singletonKey == "installation" }
        )
        descriptor.fetchLimit = 1
        guard let metadata = try modelContext.fetch(descriptor).first,
              let identifier = DwellIdentifier(rawValue: metadata.installationID)
        else {
            return nil
        }
        return InstallationRecord(
            installationID: identifier,
            createdAt: metadata.createdAt
        )
    }
}

/// Stable metadata-store failures.
public enum MetadataStoreError: String, Error, Sendable {
    case installationMismatch = "installation-mismatch"
}
