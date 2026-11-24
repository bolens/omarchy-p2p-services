# Security policy

[Documentation](DOCUMENTATION.md)

## Supported versions

Security fixes are provided for the latest release.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/bolens/omarchy-p2p-services/security/advisories/new).
Do not open a public issue for command injection, unsafe privilege boundaries,
process-identity errors, or information disclosure. Remove credentials, private
endpoints, usernames, paths, and unrelated personal information.

## Trust boundaries

The user-facing [privacy and diagnostics guide](https://bolens.github.io/omarchy-p2p-services/#privacy)
describes what can be shared safely. The invariants below define the maintainer
contract that enforces that behavior.

- Peer, process, unit, container, and package metadata is untrusted input.
- Private mode redacts sensitive values before serialization to the UI.
- Package and service actions use fixed identifiers and argument arrays.
- System service operations cross privilege boundaries through Polkit; plugin
  helpers are not run wholesale as root.
- Custom-service definitions are validated, cannot contain shell commands, and are observation-only at both UI and CLI mutation boundaries.
- Imported settings are untrusted and sanitized before use.
- Whole-plugin support reports are aggregate-only and always privacy filtered.
- The optional event journal cannot persist arbitrary detail or service identity.
- Predictable exports, credentials, caches, and backup roots reject symlink traversal; private files use no-follow or atomic replacement.
- Process termination revalidates UID and executable identity and uses Linux pidfds when available.

## Restricted Docker discovery

The optional `/usr/local/libexec/omarchy-p2p-discover` helper is a root-owned
standalone file, executed with Python isolated mode. A per-account sudo rule
permits only that executable with no arguments. It issues fixed GET requests to
`/var/run/docker.sock`; no Docker CLI, shell, user configuration, plugin imports,
caller-supplied paths, or service-control requests run inside this boundary.

Only exact built-in P2P aliases are inspected. The output schema excludes
environment variables, mounts, command lines, health logs, arbitrary labels and
raw errors. Names, images, PIDs, Compose configuration paths, validated console
routes/ports, health, timestamps, counters and bounded lifecycle classifications
are disclosed to the authorized account. Private mode filters the resulting UI
status as usual. This is metadata access, not complete concealment of container
identities. Custom aliases cannot extend the privileged allowlist.

The collector bounds response/output sizes, container count, socket timeouts and
wall time. The unprivileged client revalidates the projection and refuses
user-writable/symlinked helpers or parent directories. Fallback containers are
observation-only unless the separate authorized-control helper and policy are
installed. Logs and configuration are never granted by restricted access. Direct
Docker and Podman access retain their existing capabilities.

Installation and updates require an administrator. Runtime needs no password,
Docker group membership, network listener, socket ACL change or daemon restart.
An alias/catalog change requires reinstalling the sealed helper after review.

## Authorized Docker controls

The optional `/usr/local/libexec/omarchy-p2p-control` is a separate root-owned
standalone Python program. The Polkit action
`io.github.bolens.p2p-services.docker-control` binds to that exact executable,
requires `auth_admin` for an active desktop session, and denies inactive/other
sessions. It does not retain authorization. No control executable or argument is
added to the passwordless discovery sudo rule. Site administrator Polkit rules
remain authoritative; verify the effective policy after installation.

The controller accepts only start, stop, restart, one canonical service ID, and
1–16 distinct full container IDs. It preflights every target and re-inspects each
immediately before operating, checks exact per-service aliases, and excludes init
sidecars. It never creates/removes containers, executes commands inside them,
accepts URLs or socket paths, reads user configuration, or imports plugin code.
Existing container configuration remains unchanged; these operations can execute
the container's already configured workload with its existing privileges.

One root-owned lock serializes requests. HTTP responses, per-request timeouts and
root execution (90 seconds) are bounded. Stop/restart uses a five-second Docker
stop timeout. The `--check` option performs the same target validation through the
same fresh authorization gate but sends no mutation. Output reports aggregate
accepted operations and errors without raw daemon data.

The UI allows time for authentication and shows authorization, applying and
verification phases. The CLI forwards termination only to its owned process
group. Once elevated, the root helper watches the original caller through a
Linux pidfd and refuses further API requests when that caller exits. A request
already accepted by Docker can finish after cancellation; cancellation does not
roll back completed operations. Refresh after a timeout or partial failure.

Install controls explicitly with `scripts/install-restricted-discovery --user
ACCOUNT --with-controls` under administrator authorization. Removing the control
policy and controller returns restricted services to observation-only operation;
discovery remains available. Custom service definitions cannot gain this control
capability. Mixed active systemd/container ownership is rejected before prompting.

## Release checklist

Run the full matrix in [TESTING.md](TESTING.md), inspect process launches and
privileged paths, keep GitHub Actions SHA-pinned with least privilege, validate
a clean `git archive`, verify its artifact attestation, and scan tracked files
for credentials and private data.

Marketplace validation is compatibility and baseline review, not a security
audit or certification.
