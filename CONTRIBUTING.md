# Contributing to Dwell

Thank you for your interest in Dwell.

## Current phase

Dwell is currently defining its contracts and implementation foundations. Before opening a substantial pull request:

1. Read the [architecture plan](docs/architecture/Dwell-architecture-plan.md).
2. Read the [accepted ADRs](docs/architecture/adrs/README.md).
3. Open an issue or discussion for significant protocol, privilege, persistence, security, or repository-boundary changes.

## Development baseline

- macOS 26 or later on Apple silicon
- Xcode 26 or later
- Swift 6

The project will document a precise supported toolchain once the initial workspace and CI are established.

## Architectural boundaries

- Dwell Core must not call vendor-specific device APIs.
- All device input and actions cross the canonical MQTT boundary.
- Vendor-specific behavior belongs in adapters.
- The daemon is the sole writer of authoritative local state.
- Sensitive actions must use the shared policy system.

Changes involving a privileged process, database, executable transformation, cloud dependency, repository split, or breaking canonical schema require an ADR.

## Licence

Unless an approved exception is clearly documented, original contributions are provided under the Mozilla Public License 2.0.

New source files should include:

```text
// Copyright © Hexela
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
```

Do not copy third-party source, schemas, fixtures, or assets into the repository without recording their provenance and licence.

## Security

Do not report suspected vulnerabilities in a public issue. Follow [SECURITY.md](SECURITY.md).

