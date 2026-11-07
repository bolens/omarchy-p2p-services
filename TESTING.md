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

`scripts/lint-qml` stages the same component and JavaScript import layout for
static validation. It loads the local, Commons and Ui qmldirs explicitly because
their module URIs differ from the source directory layout. Qt's `-i` option
replaces implicit local qmldir discovery, so all three contexts are required.

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
ShellCheck, behavior, strict QML controls and complete canonical headless runtime
suite on pull requests and pushes to `main`. Its pinned toolchain and v4.0.1
imports also serve retained GitHub callers. Preparation runs
`bash scripts/woodpecker-plugin.sh --prepare` to fetch only immutable public
imports. The required `--offline` phase runs as container user 10042 with
networking disabled; test dependencies are already in the image. Neither phase
receives publishing secrets.

The required plugin check is `ci/woodpecker/pr/plugin`. Ordinary GitHub PR
and main runs skip the duplicate plugin jobs. Reusable callers retain hosted
plugin validation by default; signed release validation explicitly enables
`release_validation: true` before publication. Use Woodpecker for manual plugin
validation. Repository links, HTML/XML, workflow security,
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

Require `ci/woodpecker/pr/site` alongside the native plugin and existing hosted
checks. Ordinary PR and main runs use the pinned native browser audit; GitHub
continues the site build, structure, HTML/XML, link, and workflow-security checks.
Reusable callers retain hosted browser validation through `release_validation`
with its default `true`; signed releases explicitly enable it. Manual GitHub
workflow dispatch also retains the hosted audit, and Woodpecker supports a manual
site run. Forks still require native approval and receive no publishing secrets.

Publishing and platform checks retain their current workflows. Review the manual
browser-image digest pin alongside the other native image pins; Dependabot does
not update Woodpecker YAML.

## Strict QML import preparation

Inside the qualified CI toolchain, use the same preparation entry point as the
native and retained hosted gates:

```sh
bash scripts/with-qml-imports.sh "$OMARCHY_PATH/shell" bash tests/run_all.sh
```

Use the clean `shell` subtree from Omarchy commit
`13f18b2cb7286fb54f87daf571a031aa6af3d8f0`. The source profile checks every one of
its 175 files, including Git blob hashes and executable modes, before copying it
into an owned temporary directory. It backports the upstream
[`b83d3df` palette qualification](https://github.com/omacom/omarchy/commit/b83d3df0840504299d3099ebf391eb8110527edd)
and gives the eleven existing anonymous token objects named component types.
Every field body and readonly slot is preserved. The installed shell is unchanged.
Unknown source contents fail preparation; the experimental compatibility canary
reports that gap rather than silently adapting an unreviewed upstream revision.

The tooling helper verifies the exact Quickshell/Qt package versions and all 72
Quickshell import files. Its private metadata copy resolves source-backed core
Margins, PopupAnchor, ObjectModel and flag typedefs. It also marks only the exact
PanelWindowInterface declaration creatable for tooling: the pinned
[interface fallback](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/window/panelinterface.hpp)
is replaced at runtime by the concrete PanelWindow backend registered by the
[Wayland plugin](https://github.com/quickshell-mirror/quickshell/blob/4f508be500dea6e5732cc3d50382a0048b17e7b1/src/wayland/init.cpp).
This corrects [upstream tooling issue543](https://github.com/quickshell-mirror/quickshell/issues/543)
in the private, hash-verified copy without disabling the uncreatable-type check
or changing installed metadata.
`QML_TOOLING_IMPORT_ROOT` selects that copy first with `qmllint --bare` and explicit
system imports. Runtime engines use the real installed package metadata.

The policy rejects warnings. Real-linter controls must accept a supported nested
font field and reject an invalid property, nested field and type with the expected
diagnostic. A successful subprocess with the wrong diagnostic does not pass.
Preparation, source lint and these controls are separate from the explicit QML
runtime suite; a static pass does not prove live desktop behavior. Run runtime
harnesses only with owned HOME/XDG roots and an isolated display appropriate to
the harnesses. Window tests require a real layer-shell compositor, not the
offscreen backend. See the QML warning validation feature's
[acceptance plan](specs/005-qml-warning-validation/plan.md).

If Qt 6.12 `qmllint` fails with empty text output, repeat its exact command with
`--json -` to read the structured diagnostics. Keep the same inputs, policy and
import arguments. Loop-analysis diagnostics can remain in the structured result
when Qt's text output is empty; an empty log never overrides a failing exit code.
Acceptance requires the complete target inventory and zero structured diagnostics.

## Required native QML validation

Woodpecker prepares only the immutable public Omarchy source in its first step.
The required plugin step then runs as container user 10042 with networking
disabled. It validates the source and tooling profiles, portable checks, strict
QML lint and real invalid controls before running every harness registered in
`tests/run_qml_runtime.sh` through `scripts/qml-runtime-fixture.py`. Optional
desktop-test selection variables do not skip this owned runtime gate.

Woodpecker 3.x reads `network_mode: none` as a direct step field; placing it
under `backend_options.docker` is ignored by the agent. Docker backend options
retain the ordinary `10042:10042` user. The server must accept the legacy
step-level field in its workflow schema. Verify the actual plugin container has
`HostConfig.NetworkMode=none` and no attached workflow network before claiming
offline acceptance; YAML lint and source assertions alone do not prove this.
Preparation and cloning retain their network access and public immutable inputs.

The fixture uses private HOME/XDG roots, canonical default typography and the
packaged font resolver. Window tests use a software headless compositor; Privacy
tests also use an isolated PipeWire registry without hardware nodes. Protocol
roundtrips establish readiness. Existing harness deadlines and natural exits
remain required; Privacy shutdown also checks the owned configuration is absent.
No host display, audio socket, device, Docker socket or privilege is required.

Each result retains its raw output in CI logs. Only exact, source-bound warnings
from explicitly asserted negative tests may pass; additional Qt, binding, type
or deprecation warnings fail. The palette contract checks all 87 declared token
fields plus eleven inherited object names, stable identities, readonly owners,
permitted child writes and reactive restoration. A missing harness, marker or
cleanup result fails validation.

## IPC monitor lifecycle and geometry fixtures

The real IPC transport case creates two widgets in reverse focus order around
one production Service-owned hub. It checks typed replies, rejected requests,
missing/foreign/conflicting focus without actions, focus changes, real member
destruction and the unchanged handler identity. The owned helper audit requires
exactly two settings reconciliations and two event reads, all accepted.

Filter and message geometry fixtures use owned layer-shell panels with keyboard
focus disabled. Actual window frames gate layout assertions after changes; they
do not activate an editable focus or change the four-second case deadlines.
These are geometry tests. Physical desktop keyboard interaction remains separate.
