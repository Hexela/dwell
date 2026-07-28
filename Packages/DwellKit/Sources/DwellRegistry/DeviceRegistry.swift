// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import DwellSchemas
import Foundation

/// Reduces canonical device facts into immutable client snapshots.
public actor DeviceRegistry {
    private struct DeviceState: Sendable {
        var displayName: String?
        var manufacturer: String?
        var model: String?
        var metadata: [String: CapabilityMetadata] = [:]
        var availability = "unknown"
        var capabilities: [String: CapabilitySnapshot] = [:]
        var revision: UInt64 = 0
    }

    private var devices: [DwellIdentifier: DeviceState] = [:]
    private var revision: UInt64 = 0

    public init() {}

    /// Reduces a validated message when it represents current device state.
    public func ingest(
        _ message: CanonicalMessage,
        from topic: CanonicalTopic,
        now: Date = Date()
    ) {
        switch topic.route {
        case let .deviceMetadata(device, _):
            guard case let .deviceMetadata(metadata) = message.body else {
                return
            }
            var state = devices[device, default: DeviceState()]
            revision += 1
            state.revision = revision
            state.displayName = metadata.deviceName
            state.manufacturer = metadata.manufacturer
            state.model = metadata.model
            for capability in metadata.capabilities {
                state.metadata[capability.capability] = capability
                if let existing = state.capabilities.first(
                    where: { $0.value.capability == capability.capability }
                ) {
                    state.capabilities[existing.key] = Self.enrich(
                        existing.value,
                        with: capability
                    )
                }
            }
            devices[device] = state

        case let .deviceState(device, component, capability):
            guard let value = Self.value(from: message.body) else {
                return
            }
            var state = devices[device, default: DeviceState()]
            let key = "\(component.rawValue)/\(capability.rawValue)"
            let observedAt = message.observedAt ?? message.publishedAt
            if let existing = state.capabilities[key],
               existing.observedAt > observedAt
            {
                return
            }
            revision += 1
            state.revision = revision
            let snapshot = CapabilitySnapshot(
                componentID: component,
                capability: capability.rawValue,
                value: value,
                observedAt: observedAt,
                revision: revision,
                isStale: Self.isStale(message: message, now: now)
            )
            state.capabilities[key] = state.metadata[capability.rawValue].map {
                Self.enrich(snapshot, with: $0)
            } ?? snapshot
            devices[device] = state

        case let .deviceAvailability(device):
            guard case let .availability(availability) = message.body else {
                return
            }
            var state = devices[device, default: DeviceState()]
            revision += 1
            state.revision = revision
            state.availability = availability.status.rawValue
            devices[device] = state

        default:
            break
        }
    }

    /// Returns all known devices in stable display order.
    public func snapshot(
        commands: [DeviceCommandSnapshot] = []
    ) -> DeviceCollectionSnapshot {
        DeviceCollectionSnapshot(
            revision: revision,
            devices: devices.map { deviceID, state in
                DeviceSnapshot(
                    deviceID: deviceID,
                    displayName: state.displayName ?? Self.displayName(for: deviceID),
                    availability: state.availability,
                    capabilities: state.capabilities.values.sorted {
                        $0.id < $1.id
                    },
                    manufacturer: state.manufacturer,
                    model: state.model,
                    commands: commands.filter { $0.deviceID == deviceID },
                    revision: state.revision
                )
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        )
    }

    private static func value(
        from body: CanonicalBody
    ) -> CapabilitySnapshot.Value? {
        switch body {
        case .deviceMetadata:
            nil
        case let .quantity(value):
            .number(value.value, unit: value.unit)
        case let .boolean(value):
            .boolean(value.value)
        case let .level(value):
            .number(value.value, unit: nil)
        case let .enumeration(value):
            .text(value.value)
        case .availability, .command, .acknowledgement:
            nil
        }
    }

    private static func enrich(
        _ snapshot: CapabilitySnapshot,
        with metadata: CapabilityMetadata
    ) -> CapabilitySnapshot {
        CapabilitySnapshot(
            componentID: snapshot.componentID,
            capability: snapshot.capability,
            value: snapshot.value,
            observedAt: snapshot.observedAt,
            revision: snapshot.revision,
            isStale: snapshot.isStale,
            displayName: metadata.displayName,
            isWritable: metadata.isWritable,
            minimum: metadata.minimum,
            maximum: metadata.maximum
        )
    }

    private static func isStale(
        message: CanonicalMessage,
        now: Date
    ) -> Bool {
        if message.quality.status == .stale {
            return true
        }
        if case let .boolean(value) = message.body,
           let validForSeconds = value.validForSeconds
        {
            return (message.observedAt ?? message.publishedAt)
                .addingTimeInterval(validForSeconds) < now
        }
        return false
    }

    private static func displayName(for identifier: DwellIdentifier) -> String {
        identifier.rawValue
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
