# Plan

Constitution check: every mutation follows user action plus non-retained native
administrator authorization, exact built-in service validation and immutable-ID
checks. Privileged helpers remain standalone root-owned copies. Tests isolate
all Docker mutations. Work in the existing dirty checkout without discarding
previous fixes or requiring an unrelated branch/integration operation.

1. Add a small standard-library controller with fixed GET/POST operations,
   canonical per-service alias parity, complete target preflight, root-owned lock,
   bounded HTTP operations, verification and read-only authorization check mode.
2. Add an auth_admin Polkit action bound to that executable and install both
   only with --with-controls. Retain the exact discovery-only sudo rule.
3. Gate capability on trusted helper/policy presence. Route restricted controls
   through pkexec; handle cancellation and forward termination to the owned
   process group. Keep the CLI service verification and ambiguity checks.
4. Update card/action policy, authorization notices and action progress/timeout
   handling without granting logs/config or changing defaults/settings schemas.
5. Add isolated authorization, malicious-target, stale-ID, partial-completion,
   cancellation, capability and UI regression tests; run full local gates.
6. Install with native administrator authorization, verify policy defaults and
   passwordless denial, then use --check for live proof without service changes.
