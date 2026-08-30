# Testing

## Full local suite

```sh
tests/run_all.sh
```

This runs focused Python catalog/registry, snapshot, action, package, settings
storage, network validation, metrics parsing, cache, backup, cross-process
contention, filesystem-failure, and integration tests. It then runs JavaScript
model and contract tests, Python compile checks, QML lint and formatting checks,
and `omarchy plugin validate`.
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

Harness sources live under `tests/qml/`; the runner links them beside the
production components in an isolated temporary directory before launch. The
harnesses exercise real QML component behavior, process integration,
settings persistence, refresh and watcher lifecycles, user interaction,
privacy boundaries, and plugin-load smoke paths. `tests/run_qml_runtime.sh` is
the canonical harness inventory; adding or removing a runtime test there avoids
maintaining a second enumerated list in documentation. Headless validation
reports an explicit skip instead of implying runtime behavior was exercised.

The required CI checks use Omarchy v4.0.1. The weekly compatibility workflow
runs portable behavior and QML import checks against v4.0.1 and the current
`quattro` branch. A `quattro` failure reports upcoming incompatibility without
blocking supported-version changes. Repository CI also runs Actionlint, link
checks, and a Lighthouse audit that requires an accessibility score of 1.00.

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

Use `--verify` to exercise capture and restoration without publishing assets,
and `--report FILE` to write a machine-readable result. Screenshot publication
is transactional: incomplete updates roll back, while recovery helpers retain
and prune interrupted state safely.

The script snapshots the existing configuration, forces `privacyFilter: true`
in both durable and shell settings, reconciles and verifies the private state,
captures tightly cropped images, strips PNG metadata, and restores the exact
prior settings and workspace. It refuses to capture if either privacy check
fails. Review every image before committing it as an additional safeguard.
