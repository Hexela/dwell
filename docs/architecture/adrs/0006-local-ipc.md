# ADR 0006: Authenticated XPC for local clients

Status: Accepted

## Context

The daemon is the sole state writer and policy authority. GUI, agent, widgets, App Intents, AppleScript, and CLI need different local permissions.

## Decision

Expose a versioned Mach XPC API. Validate audit token and signing identity, assign a role, authorize every daemon-side operation, require idempotency keys for mutations, and stream bounded updates with resume cursors. Clients never share writable stores or broker credentials.

## Consequences

Privilege boundaries and upgrades are explicit. DTO/version maintenance and signed integration tests are required. Extensions use a narrow façade and cached snapshots when lifecycle constraints prevent a live connection.

## Alternatives

Shared files/databases permit races and bypass policy. Distributed notifications lack request authentication and delivery semantics. A network API unnecessarily exposes the local surface.
