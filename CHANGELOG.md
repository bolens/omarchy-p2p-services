# Changelog

All notable changes to P2P Services are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.3] - 2026-09-01

### Fixed

- Delegate `pull-requests: read` to the reusable validation workflow so
  tag-triggered releases can start after CI path filtering was introduced.

## [0.3.2] - 2026-09-01

### Fixed

- Use stable, promptly released stream-object keys while routing container
  lifecycle events.
- Use explicit singular and plural lifecycle notification copy.
- Validate complete PNG headers before reading screenshot dimensions in tests.

## [0.3.1] - 2026-09-01

### Fixed

- Preserve QML-backed enabled-service lists across settings save,
  serialization, and reload while rejecting malformed or oversized array-like
  values with a single bounded length snapshot.
- Require Qt 6 QML tooling, publish plugin module metadata, and gate reliable
  semantic lint errors in local and CI validation.

## [0.3.0] - 2026-08-31

### Fixed

- Classify systemd, Docker, and Podman lifecycle records so clean updates report
  as updates, confirmed crashes and OOM kills remain crash alerts, and ambiguous
  restarts use neutral wording.
- Treat a process-only stop as a crash only when a recent core dump matches the
  configured executable.
- Report failed or malformed process, socket, coredump, systemd, Docker, and
  Podman probes with bounded diagnostic codes instead of silently treating
  backend data as empty.

### Changed

- Cache the boot uptime once per status snapshot instead of reading
  `/proc/uptime` for each detected systemd service.
- Keep restart-sequence and systemd-journal classification in the lifecycle
  policy module instead of duplicating it in runtime discovery.

## [0.2.1] - 2026-08-31

### Changed

- Align dependency and Node.js metadata with the maintained plugin suite.
- Validate staged release payloads before commits and add a read-only live IPC
  contract probe.
- Give the main service view a deterministic compact width while keeping every
  settings page at the same configured width.

### Fixed

- Restore visible service-card navigation for `j`/`k` and arrow keys when groups
  are collapsed; keyboard traversal reveals each destination group without
  overwriting saved collapse preferences.
- Reconcile persisted collapsed-group state when live widgets reload durable
  settings.
- Reset hidden service groups during visual audits and retain privacy-filtered
  failure crops for diagnosis.

## [0.2.0] - 2026-08-30

### Added

- Added first-class discovery, lifecycle controls, logs, configuration access,
  and package routing where available for Tailscale, ZeroTier, Nebula,
  Headscale, NetBird, NetBird Server, Netmaker, and Netmaker Client.
- Added canonical service categories with category-aware search, grouping,
  saved views, and optional per-category bar counts and icon overrides.
- Added category sorting, control-scope grouping, semantic or alphabetical group
  ordering, configurable group icons and counts, and group-safe stable sorting.

### Changed

- Consolidated settings defaults and mutation paths around the manifest contract.
- Split discovery state, registry validation, action planning, package commands,
  and refresh scheduling into focused modules with dedicated tests.
- Extracted reusable QML controllers for refreshes, service actions, and settings
  navigation to reduce duplicated process and UI coordination logic.
- Expanded architecture, security, release, and live QML validation coverage.
- Separated the static service catalog and atomic settings repository from the
  CLI orchestrator, with direct catalog and persistence tests.
- Replaced repeated boolean-setting QML wiring with one reusable control that
  owns lookup, styling, and mutation behavior.
- Unified HTTP and console-host validation across settings, custom services,
  and runtime actions, and isolated pure traffic-counter parsing.
- Split runtime probing, privacy-aware inspection, and configuration backup
  storage from the CLI; divided integration coverage by domain.
- Reduced the main widget to panel composition by extracting six settings
  pages, the service editor, filter pills, headings, and theme-role controls.
- Removed hollow compatibility wrappers and generic owner-module injection;
  stores are used directly and runtime/inspection modules declare explicit
  capabilities.
- Moved organization controls into Widget settings and reduced the main list's
  organization surface to saved-view shortcuts.
- Organization changes now invalidate captured live-sort positions immediately,
  so sort, grouping, favorite, label, and custom-order changes are visible at once.
- Ordering now has an explicit event revision, making accepted organization
  selections recompute the visible model before persistence or refresh results.
- Aggregated simultaneous service notifications and added an opt-in,
  identity-free local event journal.
- Added aggregate-only privacy-filtered support reports and contextual links to
  the relevant settings sections.
- Kept last-good data visible with a degraded bar marker and added `/` as the
  service-search shortcut.

## [0.1.0] - 2026-08-25

### Added

- Initial Omarchy Shell service and bar widget.
- Privacy-aware discovery and controls for local P2P services, systemd units,
  Docker containers, and Podman containers.
- Settings persistence, service customization, diagnostics, configuration
  backups, and package-management integration.

[Unreleased]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bolens/omarchy-p2p-services/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/bolens/omarchy-p2p-services/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bolens/omarchy-p2p-services/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bolens/omarchy-p2p-services/releases/tag/v0.1.0
