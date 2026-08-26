# Security policy

## Supported versions

Security fixes are provided for the latest release.

## Reporting a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/bolens/omarchy-p2p-services/security/advisories/new).
Do not open a public issue for command injection, unsafe privilege boundaries,
process-identity errors, or information disclosure. Remove credentials, private
endpoints, usernames, paths, and unrelated personal information.

## Trust boundaries

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

## Release checklist

Run the full matrix in [TESTING.md](TESTING.md), inspect process launches and
privileged paths, keep GitHub Actions SHA-pinned with least privilege, validate
a clean `git archive`, and scan tracked files for credentials and private data.

Marketplace validation is compatibility and baseline review, not a security
audit or certification.
