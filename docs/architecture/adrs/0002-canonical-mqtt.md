# ADR 0002: Canonical MQTT v1 JSON contract

Status: Accepted

## Context

All device facts and actions must cross MQTT, while third-party formats evolve independently and MQTT delivery can duplicate, reorder, or retain stale values.

## Decision

Use `dwell/v1/i/<installation>/...` topics and versioned UTF-8 JSON envelopes. Default to QoS 1. Retain metadata, current state, and availability; never retain ordinary commands or events. Carry message, correlation, causation, source, event/publish times, quality, expiry, and stable command IDs. Require application idempotency and freshness checks. MQTT 5 is preferred; MQTT 3.1.1 remains an MVP requirement and carries unavailable MQTT 5 semantics in the canonical envelope.

## Consequences

Messages remain diagnosable and adapters are easy to build. JSON costs bandwidth, acceptable at household scale. Schema governance and compatibility fixtures become release-critical. Exactly-once physical effects are explicitly not promised.

## Alternatives

Vendor topics in Core destroy isolation. Protobuf is smaller but harms first-release inspection/interoperability. QoS 2 does not solve physical exactly-once effects.
