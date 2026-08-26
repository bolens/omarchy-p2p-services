# Releasing

Releases are immutable, SemVer-tagged snapshots. GitHub Actions validates the
tag, creates a source archive and SHA-256 checksum, and publishes both.

## Prepare and validate

1. Update `manifest.json` to the release version.
2. Move `CHANGELOG.md` entries from Unreleased into a dated version and update
   its comparison links.
3. Update user-visible behavior in the canonical [website guide](https://bolens.github.io/omarchy-p2p-services/#guide),
   including dependencies, installation, troubleshooting, and removal when relevant.
4. Run [TESTING.md](TESTING.md), then push the release commit and require CI to
   pass on the exact candidate SHA.
5. Confirm the worktree is clean and `origin/main` matches the candidate.

## Tag and publish

```sh
version=$(jq -r .version manifest.json)
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
git tag -a "v$version" -m "P2P Services $version"
git push origin "v$version"
```

The Release workflow rejects tags that do not match the manifest version.
After it completes, verify the release assets and checksum, then install the
public repository on a clean Omarchy environment.

## Omarchy Plugins listing

Before submitting or requesting a listing refresh, confirm the public GitHub
repository has root `manifest.json`, `README.md`, `LICENSE`, and `preview.png`;
the plugin ID remains `io.github.bolens.p2p-services`; dependencies and safe
removal are documented; and `omarchy plugin validate` passes. Use category
`System` and tags `bar`, `quickshell`, and `system`.

The community marketplace validates compatibility and a limited automated
security baseline. It is not a security audit or certification. Follow the
marketplace's existing-listing verification flow after later releases rather
than opening a duplicate submission.
