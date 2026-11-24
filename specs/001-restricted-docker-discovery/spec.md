# Restricted Docker discovery

Created: 2026-11-23. Status: implemented.

## User scenarios

P1: A desktop user without Docker socket access sees built-in P2P containers,
including state, uptime, health, published console ports, and network counters.
The account gains no ability to create, execute in, modify, or stop containers.

P2: Users with existing direct Docker or Podman access retain that discovery and
control path. Missing or denied helper access degrades to the existing probes.

## Requirements and acceptance

- A root-owned standalone helper accepts no arguments and uses only fixed GET
  requests against the system Docker Unix socket. It imports no plugin code.
- Only exact canonical built-in P2P aliases are matched. Unrelated containers,
  environment variables, mount records, command lines, health output, and raw
  error text never leave the privileged boundary.
- Output, input, count, request time, and total execution are bounded. Partial
  snapshots are explicitly diagnosed. No network listener or daemon is added.
- A sudoers grant names one account, one root-owned executable, and no arguments.
  Python isolated mode excludes user site packages and environment injection.
- Fallback records are observation-only in both UI and CLI action boundaries.
  Existing directly accessible backends retain controls. Custom-only aliases
  require direct runtime access; they cannot extend the privileged allowlist.
- Installation is explicit, validates ownership and sudoers, and never changes
  Docker groups, socket permissions, or running containers. Removal is documented.
- Isolated tests cover hostile metadata, denied access, malformed responses,
  secret omission, observation-only enforcement, and existing discovery paths.

## Success criteria

The live widget discovers system Docker P2P containers without Docker group
membership; the exact helper sudo grant cannot run additional commands or take
arguments. Focused and full repository gates pass.
