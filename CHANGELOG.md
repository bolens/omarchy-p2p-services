# Changelog

All notable changes to P2P Services are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Pages code examples use theme-aware shell syntax highlighting without changing copied commands.

## [0.3.8] - 2026-09-01

### Fixed

- Recover event-journal and settings-transfer queues when a helper exceeds its deadline.

## [0.3.7] - 2026-09-01

### Fixed

- Bound pending event-journal commands by count and size so a stalled helper
  cannot grow the shared shell process indefinitely.

## [0.3.6] - 2026-09-01

### Added

- Pages now include favicons, touch and install icons, a web manifest, and a 1200x630 social card. Regression tests protect the metadata and image dimensions.

## [0.3.5] - 2026-09-01

### Fixed

- Honor injected epoch timestamps in time-dependent model behavior instead of
  silently substituting the wall clock.

## [0.3.4] - 2026-09-01

### Added

- Pages offer selectable dark and light themes.
- Browsers that prefer light mode start with GitHub Light; browsers without a preference keep the default dark theme.

## [0.3.3] - 2026-09-01

### Fixed

- Tag-triggered releases now receive the pull-request metadata required by path-filtered validation.

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

- Discovery, lifecycle controls, logs, configuration access, and package routing for Tailscale, ZeroTier, Nebula, Headscale, NetBird, and Netmaker services.
- Category-aware search, grouping, saved views, custom ordering, icons, counts, and bar presentation.
- Aggregated notifications, an optional identity-free local event journal, privacy-filtered support reports, and contextual settings links.

### Changed

- Settings, discovery, actions, package commands, probing, inspection, backups, and refresh scheduling now have explicit ownership and focused tests.
- Organization controls live in Widget settings, while the main list keeps saved-view shortcuts.
- Sort and grouping changes update the visible model before persistence or refresh results.
- The widget keeps last-good data visible during degraded probes and uses `/` for search.

### Fixed

- Shared validation now handles HTTP endpoints, console hosts, custom services, and runtime actions consistently.

## [0.1.0] - 2026-08-25

### Added

- Initial Omarchy Shell service and bar widget.
- Privacy-aware discovery and controls for local P2P services, systemd units,
  Docker containers, and Podman containers.
- Settings persistence, service customization, diagnostics, configuration
  backups, and package-management integration.

[Unreleased]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.8...HEAD
[0.3.8]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.7...v0.3.8
[0.3.7]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.6...v0.3.7
[0.3.6]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.5...v0.3.6
[0.3.5]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.4...v0.3.5
[0.3.4]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/bolens/omarchy-p2p-services/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bolens/omarchy-p2p-services/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/bolens/omarchy-p2p-services/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bolens/omarchy-p2p-services/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bolens/omarchy-p2p-services/releases/tag/v0.1.0
