# ADR 0007: Selective MQTT federation

Status: Accepted

## Context

Installations need selective real-time access without making one database multi-home or introducing a Dwell cloud dependency.

## Decision

Use mutually authenticated MQTT principals and allowlisted broker bridging (or a shared broker for controlled deployments). Pair installations explicitly and grant entity/capability/direction scopes. Target installations re-authorize every command. Use iCloud only for optional metadata or rendezvous later.

## Consequences

Real-time control remains on the authoritative bus and works over user-managed VPNs. Certificate/credential rotation, revocation, loop prevention, namespace ACLs, and freshness are required. History stays local by default.

## Alternatives

CloudKit is not a real-time control bus. Direct peer APIs add another device-action path. A shared unrestricted broker creates excessive blast radius.
