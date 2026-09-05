# omarchy-p2p-services Spec Kit project guide

A QML service-control interface backed by bounded Python discovery, action, settings,
and cache adapters.

Read this guide with `AGENTS.md` and `.specify/memory/constitution.md` before
specifying, planning, or implementing a substantial change. It is project-owned
guidance, not an upstream-managed template.

## Source and ownership map

- `Service.qml`
- `Model.js`
- `backend/`
- `p2p-control`
- `P2PActionRunner.qml`
- `P2PSettingsStore.qml`
- `TESTING.md`

## Specification and plan decisions

Distinguish requested, pending, active, failed, unavailable, and degraded service state.
Identify the controller/backend seam, allowed service identifiers, subprocess ownership,
queue limits, settings serialization, and privacy filtering.

## Acceptance evidence

Cover missing tools, invalid service names, command failure, timeout, stale refreshes,
cache invalidation, concurrent settings writes, and backup/restore failure with fake
commands and temporary state. Never turn observation into an implicit control action.

## Validation and operational limits

```sh
tests/run_all.sh --portable
```

The portable suite omits live QML behavior. Select the real-engine harnesses in
TESTING.md for affected runtime boundaries when authorized. Do not start, stop, enable,
disable, or reconfigure real peer-to-peer services during testing.

## Working through Spec Kit

Use Spec Kit for new capabilities, architectural or security-sensitive changes,
migrations, and coordinated changes that need a written contract. Keep narrow fixes,
dependency updates, and prose maintenance in the normal PR workflow.

For a new feature, record observable acceptance criteria in `spec.md`, source ownership
and constitution checks in `plan.md`, and evidence-bearing work in `tasks.md` under the
feature directory created by Spec Kit. Resolve material unknowns before implementation.
Mark tasks complete only after their stated verification, and distinguish completed,
skipped, blocked, and manual checks. Retain completed feature documents as decision
history; do not backfill feature specifications for already finished code.

Keep `.specify/templates/`, `.specify/scripts/`, and generated Codex skills under their
integration manifests. Use this guide and the constitution for local customization.
Regenerate managed files through Spec Kit and verify that project-owned memory survives
updates. Follow `RELEASING.md` for push, merge, release or delivery, and recovery.
