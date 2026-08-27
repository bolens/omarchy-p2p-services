# Architecture

## Repository map

- `BarWidget.qml` composes the panel. `P2PSettingsPanel.qml` composes six
  page-specific settings components, while `P2PServiceEditor.qml`,
  `P2PServiceActions.qml`, and the other `P2P*` components own focused
  interaction surfaces.
- `P2PRefreshController.qml` owns refresh serialization for both the shared
  service and compatibility fallback. `Service.qml` owns the keep-loaded
  watcher and shared results.
- `Model.js` owns pure presentation policy and the QML default-settings contract.
- `p2p-control` is the CLI, command execution, and privileged orchestration
  boundary. `RuntimeProbe` owns process, systemd, socket, container, and proxy
  discovery; `ServiceInspector` projects those observations into the public,
  privacy-aware status model.
- `p2p_catalog.py` is the canonical built-in service, category, package,
  container-alias, and AUR metadata source. `p2p_registry.py`, `p2p_snapshot.py`,
  `p2p_actions.py`, and `p2p_packages.py` own validation, per-request probe
  state, backend command planning, and package routing respectively.
- `p2p_settings.py` validates and reconciles settings while
  `p2p_settings_store.py` owns private locking, atomic writes, and one-step
  undo. `p2p_backup_store.py` owns configuration backup inventory, retention,
  and restoration. `p2p_cache.py` and `p2p_backups.py` isolate cache and
  privileged restore-command policy.
  Python defaults are read from `manifest.json`.
- `p2p_validation.py` is the shared security boundary for user-controlled HTTP
  URLs and console hosts. `p2p_metrics.py` owns pure container-counter parsing.
- `p2p_support.py` projects whole-plugin diagnostics into aggregate-only reports.
  `p2p_event_store.py` persists a bounded journal whose schema cannot carry
  service names or arbitrary detail.
- `tests/` contains JavaScript and Python validation, fixtures, and the
  development-only Quickshell harnesses under `tests/qml/`. The runtime runner
  links those harnesses beside production components in an isolated temporary
  directory so their relative QML topology matches an installed plugin without
  shipping test entry points.
- `.github/` contains contribution forms and CI/release automation.

Runtime files stay at the plugin root because Omarchy resolves manifest entry
points and sibling imports relative to the installed plugin directory.

## Ownership and invariants

- `Service.qml` owns shared status collection and exposes one keep-loaded model.
- `Service.qml` owns the single durable-settings watcher; monitor-specific widgets
  reconcile only when its observed revision advances beyond their local revision.
  The shared service also owns watcher health, bounded retry backoff, and telemetry.
  A handshake watchdog requires the settings watcher to emit its initial revision
  event before it is considered healthy.
- `BarWidget.qml` composes presentation state; extracted QML components own
  refresh scheduling, action dispatch, settings navigation, headers, lists,
  cards, quick controls, repeated boolean-setting mutation, and message surfaces.
- `Model.js` owns pure normalization and view policy shared with tests.
- `Model.js` also owns semantic group labels, ordering, icons, counts, and the
  invariant that stabilized live sorting never splits a group.
- `P2POrganizationState.qml` owns event revisions and captured-order lifetime;
  `P2PGroupHeader.qml` owns group summary rendering and collapse activation.
- `P2PSettingsReset.qml` owns global-default restoration while preserving
  per-service display, action, favorite, and ordering customizations.
- `P2PSettingsTransferController.qml` serializes export/import/undo subprocesses
  and publishes completed mode/payload results without relying on asynchronous
  `Process.running` transitions.
- `P2PActionRunner.qml` serializes service controls and snapshots the service and
  action associated with each subprocess result.
- `P2PDeferredRefresh.qml` retains only the latest status update while the panel
  is scrolling. `P2PServiceConfirmationController.qml` owns uninstall/restore
  targets and clears both workflows when the panel closes.
- `P2PCatalogController.qml` serializes catalog subprocesses, while
  `P2PSettingsTransferResult.qml` owns import, undo, and export-result
  application.
- `SnapshotContext` is the only owner of mutable discovery caches; adding a
  probe must extend its reset boundary.
- `RuntimeProbe`, `ServiceInspector`, `SettingsStore`, and `ConfigBackupStore`
  receive their collaborators or storage roots so tests can exercise them
  without implicit live-state dependencies.
- Extracted Python modules receive explicit capabilities rather than the CLI
  module or a generic owner object. The settings loader is retained solely as
  a lifecycle boundary: it avoids constructing six settings pages until the
  user opens settings.
- `SettingsStore` receives its storage paths and sanitizer, so persistence is
  testable without mutating process-global paths or touching live user state.
- Runtime adapters return argument arrays. Subprocess execution and privilege
  crossing remain in `p2p-control` so pure planners are independently testable.
- Private mode removes endpoints, process IDs, paths, and console URLs before
  data reaches the UI.
- Support reports force the private projection; event journal records accept
  only allowlisted kinds, bounded counts, and timestamps.
- Service, package, unit, executable, and privileged actions are allowlisted.
- Service categories flow from the canonical registry through status projection
  into search, grouping, and category bar segments; the UI does not maintain a
  parallel service-ID taxonomy.
- Runtime discovery, custom services, and settings sanitization share the same
  URL-validation policy rather than maintaining independent copies.
- Settings and backups use bounded input, private storage, locks, and atomic
  replacement.
- A service action is successful only after observed state confirms it.

Docker and Podman remain optional. Discovery degrades without either runtime or
without any supported P2P software installed.

## Performance constraints

- Keep one shared service instance; per-monitor widgets must not create their own watchers.
- Reuse snapshot indexes for processes, sockets, units, packages, and containers.
- Deduplicate equivalent multi-monitor refresh requests while preserving forced and full-scan upgrades.
- Prefer event-driven refreshes with bounded polling as recovery, not repeated unbounded subprocesses.
- Do not launch a persistent Podman event stream; Podman changes are detected by
  bounded status reconciliation because its idle event command actively polls.
- Derive catalog, grouping, count, and bar projections once per reactive snapshot.
- Run loading-animation and retry timers only while their corresponding state is active.
- Bound command output, cache entries, retries, payloads, rendered rows, and filesystem reads.

Changes that weaken these constraints require focused tests and live Quickshell verification.

## Settings contract

`manifest.json` is the canonical source of default values. Python sanitization
loads those defaults, `Model.settingsDefaults()` provides the QML reset copy,
and contract tests require exact parity. All settings mutations pass through
one revisioned commit path before durable and inline shell state are updated.
