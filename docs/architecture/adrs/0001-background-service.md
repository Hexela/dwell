# ADR 0001: Boot-time daemon and user agent

Status: Accepted

## Context

Automations must run through GUI quit, logout, crash, and reboot. Notifications, iCloud, and Apple Home are user-scoped. A menu-bar application alone cannot meet the requirement.

## Decision

Register a bundled LaunchDaemon using `SMAppService`. Start as root only as required, then run under a dedicated least-privileged account. Put automation authority, MQTT, scheduling, and durable stores there. Add an optional per-user LaunchAgent for notifications, menu UI, and future user-scoped Apple frameworks.

## Consequences

Installation needs admin approval, careful signing, clean upgrade/uninstall, and system-Keychain credential provisioning. User-scoped features become queued best-effort clients rather than core dependencies. Prototype this on clean macOS 26 systems before feature implementation.

## Alternatives

A LaunchAgent fails the logged-out requirement. A login item/menu app fails boot execution. A permanently root daemon is simpler but violates least privilege.
