# Dwell

Dwell is a native, local-first macOS home-automation platform designed to make capable household automation feel like a polished Apple product rather than a server-administration exercise.

The project is in its always-on-spine implementation phase. The initial Xcode
workspace, canonical MQTT contract, daemon/XPC foundation, broker lifecycle,
and daemon-owned persistence stores are now in place.

## Design principles

- Native macOS and SwiftUI-first
- Always-on automation independent of the management window
- MQTT as the authoritative device event and action boundary
- Local operation without a required Dwell cloud service
- Graphical setup and understandable automations
- Strong diagnostics and causal explanations
- Explicit permissions for security- and safety-sensitive actions

## Architecture

The accepted implementation baseline is documented in:

- [Architecture and implementation plan](docs/architecture/Dwell-architecture-plan.md)
- [Architecture Decision Records](docs/architecture/adrs/README.md)

## Platform

- macOS 26 or later
- Apple silicon
- Xcode 26 or later
- Swift 6

## Development

Open [`Dwell.xcworkspace`](Dwell.xcworkspace) in Xcode. The shared `Dwell`
scheme builds the management app, daemon foundation, and `dwellctl` command-line
tool together. Individual schemes are also available for each executable.

The checked-in Xcode project is generated from [`project.yml`](project.yml)
using [XcodeGen](https://github.com/yonaskolb/XcodeGen). After changing targets,
source groups, package dependencies, or build settings, regenerate it from the
repository root:

```sh
xcodegen generate --spec project.yml
```

### Development MQTT broker

The daemon can connect to an existing MQTT 3.1.1 or MQTT 5 broker during local
development. Copy `Config/development-broker.example.json` to the ignored path
`Config/development-broker.json`, then replace the example values. The
`Config/Local/development-broker.json` path is also supported and takes
precedence when both exist. Xcode embeds the selected ignored file only in
local builds so the registered daemon can read it.

This file may contain a development password and must not be committed. Durable
broker configuration and daemon-owned Keychain credential provisioning will
replace this temporary development mechanism in a later security stage.

### Daemon persistence

The daemon owns a versioned SwiftData metadata store and a GRDB operational
store under `/Library/Application Support/Dwell`. Valid canonical MQTT messages
are committed transactionally to the durable inbox and history before they are
reported as accepted. Reported state is projected for restart recovery, and
message-ID deduplication survives process restarts.

For local command-line development, `DWELL_DATA_DIRECTORY` may point the daemon
at an isolated writable directory. Production clients never open these stores
directly.

## Project status

Dwell is pre-alpha. Canonical contracts, background-service health, MQTT
lifecycle, and the first persistence/reconciliation foundation are implemented.
The first useful-device slice now restores canonical sensor/light state into an
actor-owned registry, exposes device snapshots through signed XPC, and presents
them in a native Devices screen. Ordinary on/off light requests are persisted
before non-retained MQTT publication. A Zigbee2MQTT translator has canonical
conformance coverage for temperature, on/off, and brightness payloads; managed
adapter supervision and discovery metadata remain follow-up work.

## Contributing

Contributions and design discussion are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the accepted ADRs before proposing implementation work.

## Licence

Dwell is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © Hexela.
