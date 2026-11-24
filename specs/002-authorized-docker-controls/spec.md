# Authorized Docker lifecycle controls

Created: 2026-11-23. Status: implemented.

## User scenarios

P1: A user clicks start, stop or restart for a catalogued system Docker P2P
service. A fresh native administrator prompt identifies the requested operation,
service identifier and exact container IDs. Cancellation performs no mutation.
Discovery remains passwordless without Docker group or socket permission changes.

P2: An unavailable helper/policy leaves services observation-only. Direct Docker,
Podman, systemd and custom observation-only contracts retain their behavior.

## Acceptance requirements

- A separate root-owned standalone controller permits exactly three lifecycle
  operations, fixed system Docker Unix socket, full 64-digit hexadecimal IDs,
  canonical per-service aliases and at most 16 distinct targets per request.
- Preflight all targets before any mutation and re-inspect each immediately
  before operating. Reject wrong service, stale ID, init sidecar, malformed input
  and arbitrary commands, endpoints, paths, container creation or exec.
- Polkit policy uses auth_admin without retained authentication; inactive and
  non-session callers are denied. No passwordless sudo control grant is added.
- Export capability/authorization-required state separately from data access.
  Logs and config remain unavailable through restricted Docker access.
- Pending UI distinguishes authorization, applying and verification. Cancelling
  or timing out the application terminates only its owned helper process group.
  A Docker operation already accepted by the daemon may still finish; no later
  targets are submitted after cancellation.
- Bound root execution and HTTP I/O; serialize requests at the root boundary;
  return bounded aggregate completion/failure status and verify resulting state.
- A privileged --check mode validates the exact same targets but sends no POST.
  Use it for live authorization proof; never stop real services during tests.
- Preserve the existing no-argument discovery grant and per-account install.
  Add optional control installation and document independent removal/rollback.
