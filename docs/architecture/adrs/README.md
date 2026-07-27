# Dwell architecture decision records

Each record is independently reviewable. Accepted records form the implementation baseline and may be changed only by a superseding ADR.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-background-service.md) | LaunchDaemon plus user LaunchAgent | Accepted |
| [0002](0002-canonical-mqtt.md) | Canonical versioned JSON over MQTT | Accepted |
| [0003](0003-persistence.md) | SwiftData metadata plus GRDB operational/history | Accepted |
| [0004](0004-integrations.md) | Hybrid out-of-process MQTT integrations | Accepted |
| [0005](0005-automations.md) | Declarative AST with durable execution | Accepted |
| [0006](0006-local-ipc.md) | Authenticated XPC client API | Accepted |
| [0007](0007-federation.md) | Selective MQTT federation | Accepted |
| [0008](0008-apple-home.md) | Defer Apple Home bridge pending feasibility | Accepted |
| [0009](0009-repository-and-licensing.md) | MPL 2.0 monorepo with deliberate future extraction | Accepted |

The full context, diagrams, risks, roadmap, and acceptance criteria are in [Dwell architecture and implementation plan](../Dwell-architecture-plan.md).
