# Implementation plan

Use the repository Spec Kit specification/plan/tasks structure in this existing
dirty checkout, preserving prior work. Constitution review: the helper performs
no service controls, exposes explicit partial/unavailable diagnostics, and keeps
privileged execution outside all user-writable Python imports.

1. Implement a standalone Python standard-library Unix HTTP collector. Copy the
   canonical alias set into its sealed payload; enforce parity in tests.
2. Install an immutable root-owned copy and a no-argument, per-account sudo rule.
   Verify every parent directory is root-owned and not group/other writable.
3. Inject an optional discovery callback into RuntimeProbe. Use it only after
   ordinary Docker discovery fails; preserve Podman and direct Docker behavior.
4. Retain sanitized state, ports, traffic counters, and bounded lifecycle event
   classifications. Mark fallback services observation-only at every action path.
5. Run isolated hostile-input and integration tests, the full local gate, then
   install through native privilege elevation and verify live read-only output.

No settings or IPC schema changes are needed: the existing controllable field,
privacy projection, and diagnostic codes carry the resulting state.
