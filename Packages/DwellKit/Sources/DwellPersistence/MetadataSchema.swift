// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import Foundation
import SwiftData

/// The first daemon-owned metadata schema.
public enum MetadataSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [InstallationMetadata.self]
    }
}

/// The identity and creation time of the single installation served by Dwell.
@Model
public final class InstallationMetadata {
    #Unique<InstallationMetadata>([\.singletonKey], [\.installationID])

    public var singletonKey: String
    public var installationID: String
    public var createdAt: Date

    public init(
        installationID: String,
        createdAt: Date = Date()
    ) {
        singletonKey = "installation"
        self.installationID = installationID
        self.createdAt = createdAt
    }
}

/// Forward-only metadata migrations.
public enum MetadataMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [MetadataSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
