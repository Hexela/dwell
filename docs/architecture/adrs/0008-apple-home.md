# ADR 0008: Defer Apple Home exposure

Status: Accepted

## Context

Dwell would benefit from Apple Home exposure, but HomeKit controller APIs do not by themselves create a distributable software accessory bridge. HomeKit accessory distribution and Matter products carry program/certification constraints.

## Decision

Exclude Apple Home/Matter exposure from the MVP. First investigate a user-session controller adapter, then prototype a standards-compliant Matter bridge only after confirming public API, continuous-operation, certification, open-source, signing, and distribution feasibility. Never use private APIs or make critical automation depend on a logged-in user.

## Consequences

The MVP makes no misleading compatibility promise. The canonical MQTT boundary keeps a future bridge replaceable. Product messaging must explain that current Matter/HomeKit devices need an external connector.

## Alternatives

An unofficial HAP bridge creates legal, security, maintenance, and distribution risks. Treating HomeKit controller access as accessory publication is technically incorrect.
