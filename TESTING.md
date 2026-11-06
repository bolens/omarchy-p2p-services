# Testing

[Documentation](DOCUMENTATION.md)

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
Run `npm run verify:live` for read-only IPC discovery, payload, version, and
invalid-input checks against an installed plugin.

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

## Plugin suite policy

Run the shared policy checker from the P2P Services checkout to compare all
four sibling repositories:

```sh
scripts/check-plugin-suite
```

Pass one or more repository paths to check a smaller set. The canonical test
runner checks the current repository automatically.

## Woodpecker plugin validation

[Woodpecker](https://woodpecker.bolens.dev/repos) runs the plugin archive,
ShellCheck, behavior and QML lint checks on pull requests and pushes to `main`.
It uses the same immutable Omarchy toolchain image and v4.0.1 imports as
GitHub CI. The entry point is `bash scripts/woodpecker-plugin.sh` inside that
image. It requires network access only to fetch the pinned public imports
and any lockfile-based test dependencies; it receives no publishing secrets.

The required plugin check is `ci/woodpecker/pr/plugin`. Ordinary GitHub PR
and main runs skip the duplicate plugin jobs. Reusable callers retain hosted
plugin validation by default; signed release validation explicitly enables
`release_validation: true` before publication. Use Woodpecker for manual plugin
validation. Repository links, HTML/XML, browser accessibility, workflow security,
compatibility canaries, macOS, development-image builds, Pages and signed release
publication retain their GitHub workflows. Native success does not replace those
checks or prove live desktop behavior. No release is created by validation CI.

Editor image changes select a real hosted Docker build and post-create smoke
under a non-root user with a read-only image and no host Docker socket. Review
native workflow image pins monthly and after security releases; Dependabot's
Dockerfile coverage does not discover `.woodpecker/` image references.

## Woodpecker site accessibility

The native `site` workflow builds the existing Pages payload, runs its structure
tests, then runs `node scripts/audit-site.mjs` in the pinned official
Puppeteer/Chrome image. It requires an accessibility score exactly 1. The helper
awaits its own loopback HTTP listener and Chrome DevTools readiness, uses ephemeral
ports, and closes only its owned browser, profile, and server. It receives no
secrets or extra host capabilities.

The hosted browser check remains required during adoption. A source review or
local build does not establish runner success: verify the final-head native site
pipeline and genuine merged-main run before retiring hosted coverage or changing
its required checks. Publishing, signed releases, and platform checks keep their
current workflows. Review the manual browser-image digest pin alongside the
other native image pins; Dependabot does not update Woodpecker YAML.
