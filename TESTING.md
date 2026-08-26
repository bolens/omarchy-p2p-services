# Testing

## Full local suite

```sh
tests/run_all.sh
```

This runs focused Python catalog/registry, snapshot, action, package, settings
storage, network validation, metrics parsing, cache, backup, cross-process
contention, filesystem-failure, and integration tests; JavaScript model/contracts tests; Python compile
checks; QML lint and formatting checks; and `omarchy plugin validate`.
It also enforces security boundaries, release metadata, local documentation
links, preview presence, and GitHub issue-form structure.

When a usable Wayland session is present, the same command also runs the live
Quickshell harnesses. Set `P2P_RUNTIME_TESTS=always` to make their absence a
failure, `P2P_RUNTIME_TESTS=never` to skip them explicitly, or pass `--portable`
for the language and contract checks used in headless CI.

Integration coverage is grouped by discovery, control, backups, and
settings/cache. Static QML ownership contracts live in `contracts.test.js`.

The Qt 6 Quickshell runtime harnesses can also be run directly from a graphical
Omarchy session:

```sh
tests/run_qml_runtime.sh
```

These execute model behavior, keyboard-navigation geometry with content above
the service list, queued refresh-controller behavior using real Quickshell
`Process` objects, event-driven organization state, real Services and Appearance
dropdown wiring, category icon edits, group-header rendering and collapse, and
saved-view activation. They also cover durable-settings save coalescing, service
editor persistence events, service-card state/actions, settings navigation,
header actions, shared toggle/numeric-setting behavior, real settings
reconciliation and failure signaling, refresh failure cleanup, service-list
composition/collapse, Discovery input parsing and transfer actions, and
General default/privacy behavior, package expansion and install/stop/uninstall
dispatch, service lifecycle/configuration telemetry, per-service notification
policy, Appearance density/rotation/theme-role behavior, per-service map/reset
policy, global reset preservation, real saved-view button interaction, and
settings-transfer concurrency/failure cleanup and service-action command
dispatch/serialization, result messaging, and custom-service JSON validation.
They also cover refresh merge/failure/health/cooldown policy, deferred refreshes,
watcher parsing/backoff/staleness and real debounce behavior, confirmation
cleanup, catalog serialization, transfer-result application, console URL
validation, and a real `Service.qml` plus `BarWidget.qml` plugin-load smoke test.
Headless validation reports their explicit skip instead of silently implying
that runtime behavior was exercised.

## Clean archive validation

Before release, validate exactly what Git will publish:

```sh
validation_dir=$(mktemp -d)
git archive HEAD | tar -x -C "$validation_dir"
omarchy plugin validate "$validation_dir"
```

After control, discovery, settings, or layout changes, install the checkout,
restart Omarchy Shell, inspect its logs, and exercise only actions that can be
safely reversed. Keep private mode enabled when collecting report material.

## Refreshing screenshots

Capture the real live panel, settings examples, bar widget, and marketplace
preview on an empty workspace:

```sh
scripts/capture-screenshots --monitor DP-1 --workspace 10
```

The script snapshots the existing configuration, forces `privacyFilter: true`
in both durable and shell settings, reconciles and verifies the private state,
captures tightly cropped images, strips PNG metadata, and restores the exact
prior settings and workspace. It refuses to capture if either privacy check
fails. Review every image before committing it as an additional safeguard.
