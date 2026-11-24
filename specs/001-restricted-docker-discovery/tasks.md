# Tasks

- [x] Implement bounded standalone collector and canonical alias parity.
- [x] Add least-privilege installer and unprivileged fallback client.
- [x] Integrate status, counters, lifecycle evidence, and control denial.
- [x] Verify adversarial cases and unchanged direct discovery.
- [x] Document installation, scope, limitations, and removal.
- [x] Run full gates, install, and verify the live desktop.

## Verification

- Full local suite passed: 253 Python tests, JavaScript contracts, QML lint,
  formatting, archive validation, and 60 isolated QML runtime harnesses.
- Installed helper matches the reviewed source; executable and parent ownership
  checks pass. The no-argument sudo call succeeds and extra arguments receive
  no passwordless authorization. Docker socket mode remains 0660 root:docker,
  and the desktop account remains outside the Docker group.
- Live private scan: 23 detected services, 11 active, nine Docker services
  observation-only, no diagnostics. The helper finds nine P2P containers, eight
  running, with counters available for all eight running containers.
- Live IPC and I2P details readiness passed after restarting Omarchy Shell.
- No real P2P service or container was started, stopped, or reconfigured.
