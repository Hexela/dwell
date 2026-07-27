# ADR 0004: Hybrid out-of-process integrations

Status: Accepted

## Context

Integrations may be local or remote, need secrets and permissions, evolve independently, and must not crash Core.

## Decision

Define integrations by a versioned manifest and canonical MQTT contract. Ship first-party local adapters as supervised, unprivileged executables with narrow broker credentials. Treat remote MQTT services as equal participants. Use a user helper only for user-scoped Apple frameworks. Do not load third-party code in Core.

## Consequences

Isolation, remote deployment, and independent development improve. Broker ACL provisioning, health topics, process supervision, and a conformance kit are required. Declarative setup is the common UI; signed native setup is exceptional.

## Alternatives

Compiled integrations are easy but tightly coupled. XPC plug-ins remain local and signing-heavy. Dynamic plug-ins create ABI and trust risk.
