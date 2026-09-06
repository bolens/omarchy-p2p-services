# Documentation

Service observation, explicit control, and settings persistence.

## Start here

| Need | Owning document |
| --- | --- |
| Use the project | [README.md](README.md) |
| Change the repository | [AGENTS.md](AGENTS.md) |
| Deliver or recover | [RELEASING.md](RELEASING.md) |
| Plan substantial changes | [.specify/memory/project-guide.md](.specify/memory/project-guide.md) |
| Non-negotiable constraints | [.specify/memory/constitution.md](.specify/memory/constitution.md) |

## Architecture

[ARCHITECTURE.md](ARCHITECTURE.md) owns the QML controller and Python backend boundaries.
Observation must stay distinct from control. Preserve allowed service identifiers, bounded
processes, queue behavior, and honest pending, unavailable, or failed states.
[SECURITY.md](SECURITY.md) owns the trust contract.

## Deployment and recovery

[README](README.md) and the linked user guide own installation and operation.
[RELEASING.md](RELEASING.md) owns plugin delivery and recovery. [TESTING.md](TESTING.md) uses fake
service commands and isolated state. Installing a plugin does not authorize changing managed
services.

## Database and state

Backend cache, event history, and user settings have different retention needs. [The
backend](backend) and [settings store](P2PSettingsStore.qml) own serialization and persistence. Use
their backup/restore paths rather than replacing the entire shell configuration. Cache refresh must
not imply a successful service action.

## Documentation maintenance

Keep decisions, invariants, failure modes, and recovery requirements in the owning document. Link to
commands, defaults, schemas, and generated catalogs instead of copying them. Change the owner and
affected references together. Update this index when adding or moving a guide, and verify relative
links and heading anchors. Historical specs and audits describe their recorded revision, not current
runtime proof. A topic without an implementation stays explicitly unimplemented.

## Topic guides

- [Website and user guide](https://bolens.github.io/omarchy-p2p-services/):
  canonical installation, usage, supported-service, configuration, privacy,
  performance, troubleshooting, and removal guidance.
- [README](README.md): concise project overview and contributor entry points.
- [Architecture](ARCHITECTURE.md): runtime ownership, invariants, security, and performance constraints.
- [Testing](TESTING.md): portable, QML runtime, capture, and clean-archive validation.
- [Releasing](RELEASING.md): versioning, tagging, publishing, and marketplace checks.
- [Security](SECURITY.md): supported versions, reporting, privacy boundaries, and threat model.
- [Support](SUPPORT.md): troubleshooting and appropriate issue channels.
- [Contributing](CONTRIBUTING.md): development workflow and pull-request expectations.

User-facing facts belong in the website guide. Repository documents should link to the relevant
guide anchor instead of maintaining a second copy; keep this index focused on contributor and
maintainer material.

- [Editor setup](.vscode/README.md)
