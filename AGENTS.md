# Agent guidance

Before Spec Kit planning or implementation, read
`.specify/memory/project-guide.md` with the project constitution. It maps
requirements to this repository's source, acceptance evidence, and validation.

Read `.specify/memory/constitution.md`, `SECURITY.md`, `ARCHITECTURE.md`, `TESTING.md`, and `CONTRIBUTING.md` when present.

- Never control real services during tests or diagnosis without explicit authorization.
- Keep service identifiers and command arguments allowlisted; preserve least privilege and bounded process scope.
- Serialize settings changes and distinguish requested, pending, active, failed, unavailable, and degraded state.
- Update QML metadata, defaults, settings UI, IPC, docs, adapters, and tests together; run the repository’s focused and full local gates.

## Spec-driven changes

Use Spec Kit for new capabilities, architecture, security-sensitive behavior,
migrations, and coordinated multi-file changes. Keep narrow fixes, dependency
updates, prose edits, and release housekeeping in the normal repository
workflow unless their risk warrants a written specification. Keep completed
feature directories under `specs/` as decision history; do not backfill them for
finished work.
