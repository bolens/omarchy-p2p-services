# Tasks

- [x] Add locked development tools and source-free image adapters.
- [x] Pass portable tests and adapter regressions in devenv and Podman.
- [x] Verify native Linux/macOS and Linux Docker checks on the recorded main revision.
- [x] Verify merged source delivery and the applicable main-revision workflows.

Historical pre-merge observation (superseded by the receipt below):
Native devenv and actual rootless Podman passed 238 Python tests, all JavaScript contracts, plugin policy, and Ruby issue-form validation. The image supplies the trusted Python interpreter path and comparison utilities. Live QML/service checks remain outside the portable gate; Docker/native macOS CI and Apple execution evidence remain pending.

## Delivery verification — 2026-09-06

The [development workflow](https://github.com/bolens/omarchy-p2p-services/actions/runs/34028957054) passed on
`870ca7665de64e12748ea82cc9c219177c9e4fcc`. Both native platform jobs ran successfully;
the Linux job also executed and passed the Docker development-image check. All
applicable workflows observed for that main revision completed successfully.

Actual Apple container-engine execution remains unverified. Native macOS devenv
validation does not establish that engine's runtime behavior. Existing live-host
and optional dependency limits still apply. Checkout cleanup remains part of each
task's delivery procedure and is not inferred from CI success.
