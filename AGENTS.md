# Agent guidance

[Documentation](DOCUMENTATION.md) maps architecture, deployment, state, and document ownership.

For behavior or architecture changes, read [.specify/memory/constitution.md](.specify/memory/constitution.md)
and the relevant parts of [ARCHITECTURE.md](ARCHITECTURE.md). Use [TESTING.md](TESTING.md) to select and run
checks, and [CONTRIBUTING.md](CONTRIBUTING.md) for commit and contribution requirements. Read
[SECURITY.md](SECURITY.md) before changing detection, control, commands, or trust boundaries.

- Never control real services during tests or diagnosis without explicit authorization.
- Keep service identifiers and command arguments allowlisted; preserve least privilege and bounded process scope.
- Serialize settings changes and distinguish requested, pending, active, failed, unavailable, and degraded state.
- Update QML metadata, defaults, settings UI, IPC, docs, adapters, and tests together; run the repository’s focused and full local gates.

## Planning and evidence

Use the [project guide](.specify/memory/project-guide.md) and
[constitution](.specify/memory/constitution.md) for substantial changes. The guide
owns Spec Kit scope, retained history, retrospective requirements, and acceptance
evidence. Prose maintenance uses the normal repository workflow.

## Context and handoffs

- Search before reading. Use bounded source excerpts for exploratory reads over
  350 lines, and inspect required guidance and actual source before editing.
- When delegation is permitted, assign a bounded question or output, paths, and
  check. Return source locations, changes, and verification gaps for final review.
- Keep durable corrections in the [project guide](.specify/memory/project-guide.md)
  or owning contract. Replace superseded advice and read it before reuse.
  Temporary progress belongs in task notes. Preserve existing authority rules.
