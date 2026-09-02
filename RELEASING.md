# Releasing

Releases are immutable, SemVer-tagged snapshots. GitHub Actions validates the
tag and publishes a source archive, a SHA-256 checksum, and a provenance
attestation.

## Prepare and validate

1. Update `manifest.json` to the release version.
2. Move `CHANGELOG.md` entries from Unreleased into a dated version and update
   its comparison links.
3. Update user-visible behavior in the canonical [website guide](https://bolens.github.io/omarchy-p2p-services/#guide),
   including dependencies, installation, troubleshooting, and removal when relevant.
4. Run [TESTING.md](TESTING.md), push a release branch, and open a pull request.
   Require CI and review conversations to pass on the exact candidate SHA.
5. Squash-merge the pull request and delete its branch. Do not push directly
   to `main`; rebase merges, merge commits, and protection bypasses are disabled.
6. Confirm the worktree is clean and `origin/main` matches the merged candidate.

## Tag and publish

```sh
version=$(jq -r .version manifest.json)
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
git tag -s "v$version" -m "P2P Services $version"
git push origin "v$version"
```

The Release workflow rejects tags that do not match the manifest version.
After it completes, verify the release assets and checksum, then install the
public repository on a clean Omarchy environment.

Verify the archive provenance before installation:

```sh
gh attestation verify "p2p-services-$version.tar.gz" \
  --repo bolens/omarchy-p2p-services
```

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

## Recovery

Never move a published tag. Fix a public defect with a new patch release. If a
workflow fails before publication, correct the release branch and replace only
an unpublished tag. Preserve the tag SHA, CI run, checksum, attestation result,
clean-install smoke, Pages display, and marketplace status as release evidence.

Fleet policy: <https://github.com/bolens/.github/blob/main/RELEASING.md>.
