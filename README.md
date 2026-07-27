# Dwell

Dwell is a native, local-first macOS home-automation platform designed to make capable household automation feel like a polished Apple product rather than a server-administration exercise.

The project is in its architecture and implementation-foundation phase. The
initial Xcode workspace, executable targets, canonical MQTT topic contract, and
contract tests are now in place.

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
replace this temporary development mechanism in the persistence phase.

## Project status

Dwell is pre-alpha. The first implementation phase is establishing the
canonical MQTT schemas, repository and test harness, background-service
feasibility, and security boundaries.

## Contributing

Contributions and design discussion are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the accepted ADRs before proposing implementation work.

## Licence

Dwell is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © Hexela.
