// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0.

import DwellDomain
import SwiftUI

struct CapabilityControlView: View {
    let capability: CapabilitySnapshot
    let command: DeviceCommandSnapshot?
    let setValue: (CapabilitySnapshot.Value) -> Void

    @State private var level = 0.0

    var body: some View {
        LabeledContent(capability.displayName) {
            HStack(spacing: 8) {
                control

                if capability.isStale {
                    Label("Stale", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }

                if let command {
                    CommandStatusView(command: command)
                }
            }
        }
        .onAppear {
            if case let .number(value, _) = capability.value {
                level = value
            }
        }
        .onChange(of: capability.value) {
            if case let .number(value, _) = capability.value {
                level = value
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch capability.value {
        case let .boolean(value):
            if capability.isWritable {
                Button(value ? "Turn Off" : "Turn On") {
                    setValue(.boolean(!value))
                }
                .disabled(command?.status == .pending)
            } else {
                Text(value ? "On" : "Off")
            }

        case let .number(value, unit):
            if capability.isWritable,
               let minimum = capability.minimum,
               let maximum = capability.maximum
            {
                Slider(
                    value: $level,
                    in: minimum...maximum,
                    onEditingChanged: { isEditing in
                        if !isEditing {
                            setValue(.number(level, unit: unit))
                        }
                    }
                )
                .frame(minWidth: 160)
                .disabled(command?.status == .pending)
                Text(level, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            } else {
                Text(value, format: .number.precision(.fractionLength(0...2)))
                if let unit {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            }

        case let .text(value):
            Text(value)
        }
    }
}

private struct CommandStatusView: View {
    let command: DeviceCommandSnapshot

    var body: some View {
        switch command.status {
        case .pending:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Command pending")
        case .applied:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Command applied")
        case .rejected, .failed, .expired, .timedOut, .unknownOutcome:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Command \(command.status.rawValue)")
                .help("Command \(command.status.rawValue)")
        }
    }
}
