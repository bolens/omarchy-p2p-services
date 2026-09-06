# Implementation plan

Own root devenv files, the container adapter and tests, ignored state, archive exclusions, development documentation, and filtered environment CI. Keep plugin runtime sources, metadata, settings, release version, and user configuration unchanged. Use Python, Node 24, Ruby, Bash, Git, jq, and GNU utilities.

Run the existing portable suite in devenv and a real Podman image; validate Linux Docker and native macOS in CI where possible. Record unsupported runtime boundaries and Apple execution limits explicitly. Follow RELEASING.md for protected merge; development tooling alone needs no plugin release.
