# ADR 0003: Split metadata and operational persistence

Status: Accepted

## Context

User configuration is a modest object graph suited to SwiftData. History, traces, timers, inbox/outbox, retention, and aggregation are append-heavy and require explicit SQL behavior.

## Decision

Let the daemon own SwiftData metadata and a GRDB-backed SQLite operational/history database. Link by immutable IDs and resumable projections. Copy an immutable automation revision into the operational database before activation.

GRDB is the approved implementation dependency, but Dwell-owned persistence protocols and conformance tests must prevent it becoming an irreversible public contract. A material problem discovered during an implementation spike may justify replacement through a superseding ADR.

## Consequences

SwiftUI-friendly metadata and predictable time-series operations are both available, at the cost of two migration systems and no cross-store transactions. Projection reconciliation and backups are mandatory.

## Alternatives

SwiftData-only leaves retention/aggregation control uncertain. GRDB-only gives more control but discards the preferred framework. PostgreSQL adds unjustified MVP operations.
