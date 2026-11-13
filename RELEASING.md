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
   Require the exact merged-commit checks described below before tagging.

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

## Required merge checks

Protected `main` requires an up-to-date pull request, resolved conversations and
these five check contexts on the reviewed candidate:

- `Repository` (GitHub Actions app 15368).
- `ci/woodpecker/pr/repository`.
- `Development environment` (GitHub Actions app 15368).
- `ci/woodpecker/pr/plugin`.
- `ci/woodpecker/pr/site`.

Require every context before an ordinary squash merge; missing, pending or failed
checks do not authorize a bypass. Woodpecker plugin, site and repository results
cover their native suites separately. They do not replace retained GitHub repository,
development-environment, platform or signed-release validation, and none of
these CI results establishes physical desktop behavior.

## Observe the exact merged candidate

After the squash merge, record its `mergeCommit.oid`, fetch `main` and require
that commit to match the release candidate. Fast-forward only a clean local main
checkout. Query runs by the exact commit and push event, select the applicable
run ID, then let `gh run watch` observe its terminal state:

```sh
repo=bolens/omarchy-p2p-services
release_sha=$(gh pr view "$pr" --repo "$repo" --json mergeCommit --jq .mergeCommit.oid)
git fetch origin main
test "$release_sha" = "$(git rev-parse origin/main)"
gh run list --repo "$repo" --commit "$release_sha" --event push \
  --json databaseId,workflowName,headSha,status,conclusion
run_id=$(gh run list --repo "$repo" --workflow CI --commit "$release_sha" \
  --event push --limit 1 --json databaseId --jq '.[0].databaseId // empty')
test -n "$run_id"
gh run watch "$run_id" --repo "$repo" --exit-status
gh api "repos/$repo/commits/$release_sha/check-runs?per_page=100" \
  --jq '.check_runs[] | {name,head_sha,status,conclusion,app_id:.app.id}'
gh api "repos/$repo/commits/$release_sha/status" \
  --jq '.statuses[] | {context,state,target_url}'
```

An absent run or status is pending evidence; inspect the matching push event
before proceeding. Do not replace missing results with a fixed sleep or retry
count. Watch the exact development-environment run ID from the same commit as
well. Require successful `Repository` and `Development environment` check runs
from app 15368, plus successful `ci/woodpecker/push/repository`,
`ci/woodpecker/push/plugin` and `ci/woodpecker/push/site` statuses. A PR success
belongs to its PR head and does not establish acceptance of the squash SHA.
Retain the commit, run URLs and native pipeline URLs. Fix a failed merged
candidate through a new pull request before tagging.

## Source lint

The native repository pipeline checks maintained python, javascript, css files selected by
[`.github/source-lint.json`](.github/source-lint.json) on every pull request
and push to `main`. Existing native checks remain part of the merge gate.
Use the [shared local reproduction instructions](https://github.com/bolens/.github/blob/7603518f305fb76f7bb1b9979f2692521f633b82/docs/source-lint.md)
with the same tooling revision pinned in
[the native policy helper](scripts/woodpecker-repository.sh). Review exclusions when adding
source files; generated and imported files retain their native validation.
Require the native repository check to pass on the current PR head before merging.

## Woodpecker plugin validation

[Woodpecker](https://woodpecker.bolens.dev/repos) runs the plugin archive,
ShellCheck, behavior, strict QML controls and complete canonical headless runtime
suite on pull requests and pushes to `main`. Its pinned toolchain and v4.0.1
imports also serve retained GitHub callers. Preparation runs
`bash scripts/woodpecker-plugin.sh --prepare` to fetch only immutable public
imports. Preparation fetches the pinned Omarchy revision with a blob-filtered
cone checkout of the complete `shell` and `bin` trees. It verifies the required
objects and working files before offline validation. Lazy fetching is disabled
during that validation. The required `--offline` phase runs as container user
10042 with networking disabled. The image supplies the Qt toolchain and plugin
test tools. Neither phase receives publishing secrets.

Woodpecker 3.x reads `network_mode: none` as a direct step field; placing it
under `backend_options.docker` is ignored by the agent. Docker backend options
retain the ordinary `10042:10042` user. The server must accept the legacy
step-level field in its workflow schema. Verify the actual plugin container has
`HostConfig.NetworkMode=none` and no attached workflow network before claiming
offline acceptance; YAML lint and source assertions alone do not prove this.
Preparation and cloning retain their network access and public immutable inputs.

The required plugin check is `ci/woodpecker/pr/plugin`. Ordinary GitHub PR
and main runs skip the duplicate plugin jobs. Reusable callers retain hosted
plugin validation by default; signed release validation explicitly enables
`release_validation: true` before publication. Use Woodpecker for manual plugin
validation. Repository links, HTML/XML, workflow security,
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

Require `ci/woodpecker/pr/site` alongside the native plugin and existing hosted
checks. Ordinary PR and main runs use the pinned native browser audit; GitHub
continues the site build, structure, HTML/XML, link, and workflow-security checks.
Reusable callers retain hosted browser validation through `release_validation`
with its default `true`; signed releases explicitly enable it. Manual GitHub
workflow dispatch also retains the hosted audit, and Woodpecker supports a manual
site run. Forks still require native approval and receive no publishing secrets.

Publishing and platform checks retain their current workflows. Review the manual
browser-image digest pin alongside the other native image pins; Dependabot does
not update Woodpecker YAML.

## QML compatibility profiles

After the Qt 6.12 compatibility update, stale plugin code may survive a hot reload.
Finish active captures, then run `omarchy restart shell` if old code or warnings
remain. See [Omarchy #6981](https://github.com/omacom/omarchy/issues/6981) for the
upstream cache issue and restart workaround.

Refresh the source and tooling profiles with the toolchain. Verify every imported
file against its immutable upstream source and keep the palette backport and
metadata projection explicit. Require real valid/invalid lint controls and the
complete existing runtime inventory before accepting a new profile. Preserve the
older/current palette and token-engine comparison as compatibility evidence.
Update native, retained release-validation and compatibility image digests only
after the actual published image has passed admission. Keep these maintainer
helpers out of the release archive through the existing `scripts/` and `tests/`
export exclusions; release validation still checks the actual distributable.

## Native repository checks

The credential-free `repository` workflow adds the existing shared Source lint,
workflow security, changelog, HTML/XML and documentation-link policies on each
PR, main push and manual native run. It builds/tests the site for link discovery;
the separate `site` workflow retains the actual Lighthouse accessibility audit.
Privacy-specific issue-form, release metadata and docs checks remain mandatory
where applicable. Run `bash scripts/woodpecker-repository.sh` in the documented
Linux tooling container to reproduce the public-tool bootstrap and checks.

The duplicate GitHub Source lint workflow is disabled after accepted native PR
and genuine-main proof. Protected `main` requires `ci/woodpecker/pr/repository`
in its place. The hosted `Repository` and `Development environment` checks remain
required alongside the native plugin and site checks. Preserve
`ci.yml`'s reusable release-validation interface and all release, platform and
Pages deployment boundaries. No future pipeline or merge is accepted by this text.
