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

Running a privileged development daemon requires the app and embedded daemon
to be signed by an Apple Development team. A “Sign to Run Locally” ad-hoc
build can run the management app, but macOS will reject its registered
LaunchDaemon. Signing and build settings are maintained directly in the
checked-in Xcode project. The app detects an ad-hoc build and avoids
unregistering a working signed service.

`Dwell.xcodeproj` is authoritative. Add targets, files, dependencies, signing,
and build settings directly in Xcode; do not regenerate or replace the project
from an external project specification.

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
The first useful-device slice now restores canonical sensor/light state and
retained discovery metadata into an actor-owned registry, exposes device and
durable command-lifecycle snapshots through signed XPC, and generates native
controls from canonical capability metadata. Zigbee2MQTT devices retain stable
IEEE-derived Dwell IDs across friendly-name changes. The supervised adapter
publishes canonical temperature, on/off, brightness, metadata, availability,
and command acknowledgements, while bounded crash restart prevents an adapter
crash loop. On/off and brightness requests are persisted before publication;
the Devices screen presents pending, applied, failed, and timed-out outcomes
without treating desired state as reported state. Guided onboarding, rooms,
generic topic mapping, and the MQTT Inspector remain Phase 2 follow-up work.

## Contributing

Contributions and design discussion are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the accepted ADRs before proposing implementation work.

## Licence

Dwell is licensed under the [Mozilla Public License 2.0](LICENSE).

Copyright © Hexela.
