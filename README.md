# Dwell

Dwell is a native, local-first macOS home-automation platform designed to make capable household automation feel like a polished Apple product rather than a server-administration exercise.

The project is currently in its architecture and protocol-definition phase. Application implementation has not started.

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

## Project status

Dwell is pre-alpha. The first implementation phase will establish the canonical MQTT schemas, repository and test harness, background-service feasibility, and security boundaries.

## Contributing

Contributions and design discussion are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the accepted ADRs before proposing implementation work.

## Licence

Dwell is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © Hexela.

