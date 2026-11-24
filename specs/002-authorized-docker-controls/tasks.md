# Tasks

- [x] Implement standalone controller, target validation and root serialization.
- [x] Add Polkit policy and optional installation with unchanged discovery grant.
- [x] Integrate capability, cancellation, control boundaries and result handling.
- [x] Add authorization-aware UI action state and regression tests.
- [x] Document threat boundary, installation, cancellation and rollback behavior.
- [x] Run full gates, install and verify live authorization without mutations.

## Verification

- Full local suite passed: 277 Python tests, JavaScript contracts, QML lint,
  formatting, archive validation and 61 isolated QML runtime harnesses.
- Installed controller exactly matches the reviewed source; its path and policy
  have root-owned, non-writable parent chains. Polkit reports auth_admin for
  active sessions and no for inactive/other sessions, without retained auth.
- A native --check request validated one real Syncthing container, accepted zero
  mutation requests, and returned mutated=false. Non-interactive policy checks
  challenged for fresh authentication before and afterward (status 2/auth_admin).
- Passwordless controller execution is denied. The discovery sudo rule remains
  no-argument and discovery-only. Docker socket mode stays 0660 root:docker; the
  desktop account is not in the Docker group.
- Live private status: 23 services, 11 active, nine restricted Docker services
  with authorizationRequired=true and controls enabled, no diagnostics. Live IPC
  and service-details readiness passed after reloading Omarchy Shell.
- No real container was started, stopped or restarted. Mutation behavior was
  verified with simulated Docker responses; live proof used validation-only mode.

The plugin smoke fixture now isolates revision reconciliation (its helper is
stateless), observes the saved acknowledgement independently of the transient
notice, and waits for catalog settlement with a bounded deadline. Dedicated
revision/store harnesses continue to exercise real reconciliation behavior.
