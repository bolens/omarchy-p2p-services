# Plan: Bounded service discovery, control, and private settings

The [specification](spec.md) preserves existing behavior. Use the project guide
and constitution for implementation constraints. Keep upstream-managed templates,
helpers, and integration manifests unchanged.

## Source ownership

- `Model.js`
- `Service.qml`
- `p2p-control`
- `backend`
- `P2PActionRunner.qml`
- `P2PRefreshController.qml`
- `P2PSettingsStore.qml`
- `manifest.json`
- `tests`

## Constitution check

Preserve stock-shell compatibility, explicit mutation authority, deterministic ownership, private data boundaries, and isolated verification. This retrospective documentation change adds no runtime behavior, deployment, or release tag.

## Validation

```sh
tests/run_all.sh --portable
```

Run checks in an isolated checkout. Commands are instructions, not evidence of
a pass. Record results in `coverage.md`, keep incomplete work in `tasks.md`, and
follow `RELEASING.md` for reviewed delivery. No live operation is required solely
to create this retrospective baseline.
