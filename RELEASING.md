# Releasing

[Documentation](DOCUMENTATION.md)

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

## Source lint

The Source lint workflow checks maintained python, javascript, css files selected by
[`.github/source-lint.json`](.github/source-lint.json) on every pull request
and push to `main`. Existing native checks remain part of the merge gate.
Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same tooling revision pinned in
[the workflow](.github/workflows/source-lint.yml). Review exclusions when adding
source files; generated and imported files retain their native validation.
Require the new check to pass on the current PR head before merging.

## Woodpecker plugin validation

[Woodpecker](https://woodpecker.bolens.dev/repos) runs the plugin archive,
ShellCheck, behavior and QML lint checks on pull requests and pushes to `main`.
It uses the same immutable Omarchy toolchain image and v4.0.1 imports as
GitHub CI. The entry point is `bash scripts/woodpecker-plugin.sh` inside that
image. It requires network access only to fetch the pinned public imports
and any lockfile-based test dependencies; it receives no publishing secrets.

The required plugin check is `ci/woodpecker/pr/plugin`. Ordinary GitHub PR
and main runs skip the duplicate plugin jobs. Reusable callers retain hosted
plugin validation by default; signed release validation explicitly enables
`release_validation: true` before publication. Use Woodpecker for manual plugin
validation. Repository links, HTML/XML, browser accessibility, workflow security,
compatibility canaries, macOS, development-image builds, Pages and signed release
publication retain their GitHub workflows. Native success does not replace those
checks or prove live desktop behavior. No release is created by validation CI.

Editor image changes select a real hosted Docker build and post-create smoke
under a non-root user with a read-only image and no host Docker socket. Review
native workflow image pins monthly and after security releases; Dependabot's
Dockerfile coverage does not discover `.woodpecker/` image references.

## Woodpecker site accessibility

The native `site` workflow builds the existing Pages payload, runs its structure
tests, then runs `node scripts/audit-site.mjs` in the pinned official
Puppeteer/Chrome image. It requires an accessibility score exactly 1. The helper
awaits its own loopback HTTP listener and Chrome DevTools readiness, uses ephemeral
ports, and closes only its owned browser, profile, and server. It receives no
secrets or extra host capabilities.

The hosted browser check remains required during adoption. A source review or
local build does not establish runner success: verify the final-head native site
pipeline and genuine merged-main run before retiring hosted coverage or changing
its required checks. Publishing, signed releases, and platform checks keep their
current workflows. Review the manual browser-image digest pin alongside the
other native image pins; Dependabot does not update Woodpecker YAML.
