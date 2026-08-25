# Changelog

All notable changes to P2P Services are documented here. This project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [0.1.0] - 2026-08-25

### Added

- Initial Omarchy Shell service and bar widget.
- Privacy-aware discovery and controls for local P2P services, systemd units,
  Docker containers, and Podman containers.
- Settings persistence, service customization, diagnostics, configuration
  backups, and package-management integration.

[Unreleased]: https://github.com/bolens/omarchy-p2p-services/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bolens/omarchy-p2p-services/releases/tag/v0.1.0
