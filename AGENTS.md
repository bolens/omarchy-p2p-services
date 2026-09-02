# Agent guidance

Read `.specify/memory/constitution.md`, `SECURITY.md`, `ARCHITECTURE.md`, `TESTING.md`, and `CONTRIBUTING.md` when present.

- Never control real services during tests or diagnosis without explicit authorization.
- Keep service identifiers and command arguments allowlisted; preserve least privilege and bounded process scope.
- Serialize settings changes and distinguish requested, pending, active, failed, unavailable, and degraded state.
- Update QML metadata, defaults, settings UI, IPC, docs, adapters, and tests together; run the repository’s focused and full local gates.
