# ADR 0009: MPL 2.0 monorepo with deliberate future extraction

Status: Accepted

## Context

Dwell ships several processes and contains reusable modules, schemas, adapters, fixtures, and documentation. During the MVP these components will evolve together. Splitting them immediately would require coordinated package releases, compatibility matrices, dependency-update pull requests, and cross-repository changes before their public contracts are stable.

Dwell should remain open source while encouraging improvements to modified Dwell source files and permitting independent integrations or larger works under other compatible terms.

## Decision

License original Dwell source under the Mozilla Public License 2.0, with an additional `Copyright © Hexela` notice.

Develop Dwell initially in the public GitHub repository `Hexela/dwell`, administered initially through the `dominictristram` account and public from its first commit. Keep runtime and dependency boundaries enforceable through Xcode targets, Swift modules, separate executables, dependency tests, `CODEOWNERS`, and documented public APIs rather than through repository proliferation.

The monorepo contains the macOS application, daemon, user agent, widgets, CLI, first-party adapters, local Swift packages, canonical MQTT schemas, fixtures, tests, installer/release configuration, and architecture documentation. Product releases use one coordinated version.

The repository includes the full MPL 2.0 licence, standard Exhibit A notices where practical, third-party notices and provenance, and automated licence checks. The project does not apply the Exhibit B “Incompatible With Secondary Licenses” notice unless a later ADR establishes a specific need.

## Extraction criteria

A component may move to its own repository only through another ADR and normally after at least three of the following are demonstrated:

- external consumers;
- independent maintainers;
- an independent release cadence;
- a stable, versioned public contract;
- an independent build and test workflow;
- distinct access or security ownership;
- a substantially different toolchain;
- cross-repository changes are expected to be exceptional.

The likely first extraction is an integration SDK containing MQTT schemas, manifest definitions, adapter helpers, conformance tests, fixtures, and an example. Independently maintained vendor integrations and non-Swift SDKs may follow. The daemon, app, persistence, automation engine, and internal IPC modules are not extraction candidates during the MVP.

## Consequences

Schema, adapter, Core, fixture, and documentation changes can land atomically. Contributors can build and test the whole product from one revision, while module boundaries still prevent vendor logic from entering Core.

The repository and CI will be larger, and permissions cannot be separated as strongly as they could across repositories. `CODEOWNERS`, protected environments, and restricted release-signing credentials mitigate this. Future extraction requires compatibility contracts and history-preserving migration work.

MPL obligations follow covered source files rather than Git repository boundaries. Splitting a repository is therefore an engineering and governance decision, not a mechanism for changing the licence’s scope.

## Alternatives

A repository per executable mirrors deployment but creates unnecessary coordination and obscures end-to-end compatibility. Extracting every Swift package makes internal API changes expensive. A single unstructured target would reduce repository overhead but sacrifice the process, privilege, and dependency boundaries required by the architecture.
