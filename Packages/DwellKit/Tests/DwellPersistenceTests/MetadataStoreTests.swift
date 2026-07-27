// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellPersistence
import Foundation
import Testing

@Suite("Metadata store")
struct MetadataStoreTests {
    @Test("Installation identity is created once")
    func installationIdentityIsCreatedOnce() async throws {
        let store = try MetadataStore.inMemory()
        let identifier = try #require(DwellIdentifier(rawValue: "home-a"))
        let createdAt = Date(timeIntervalSince1970: 100)

        let created = try await store.loadOrCreateInstallation(
            identifier,
            now: createdAt
        )
        let reloaded = try await store.loadOrCreateInstallation(
            identifier,
            now: Date(timeIntervalSince1970: 200)
        )

        #expect(created == reloaded)
        #expect(reloaded.createdAt == createdAt)
    }

    @Test("A configured store rejects a different installation")
    func rejectsDifferentInstallation() async throws {
        let store = try MetadataStore.inMemory()
        let first = try #require(DwellIdentifier(rawValue: "home-a"))
        let second = try #require(DwellIdentifier(rawValue: "home-b"))
        _ = try await store.loadOrCreateInstallation(first)

        await #expect(throws: MetadataStoreError.installationMismatch) {
            try await store.loadOrCreateInstallation(second)
        }
    }
}
