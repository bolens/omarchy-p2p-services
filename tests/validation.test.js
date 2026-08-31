#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");

const runner = fs.readFileSync("tests/run_all.sh", "utf8");
const workflow = fs.readFileSync(".github/workflows/ci.yml", "utf8");
const pages = fs.readFileSync(".github/workflows/pages.yml", "utf8");
const release = fs.readFileSync(".github/workflows/release.yml", "utf8");
const dependabot = fs.readFileSync(".github/dependabot.yml", "utf8");
const preCommit = fs.readFileSync("scripts/pre-commit", "utf8");
const live = fs.readFileSync("scripts/verify-live", "utf8");
assert.match(runner, /P2P_RUNTIME_TESTS/);
assert.match(runner, /tests\/run_qml_runtime\.sh/);
assert.match(runner, /Runtime QML tests skipped/);
assert.match(runner, /--portable/);
assert.match(workflow, /tests\/run_all\.sh --portable/);
assert.match(runner, /git archive HEAD \| tar -x -C "\$validation_dir"/);
assert.match(runner, /omarchy plugin validate "\$validation_dir"/);
assert.match(preCommit, /archive "\$\(git -C "\$root" write-tree\)"/);
assert.match(preCommit, /P2P_RUNTIME_TESTS=never/);
assert.ok(fs.statSync(".githooks/pre-commit").mode & 0o100);
assert.match(live, /settingsSnapshot/);
assert.match(live, /settingsReady __invalid__/);
assert.doesNotMatch(live, /\b(open|close|reloadSettings)\b/,
  "live IPC verification must remain read-only");
assert.equal(JSON.parse(fs.readFileSync("package.json", "utf8")).scripts["verify:live"], "bash scripts/verify-live");
assert.doesNotMatch(workflow, /node tests\/model\.test\.js/);
assert.match(workflow, /group: ci-\$\{\{ github\.event\.pull_request\.number \|\| github\.ref \}\}/);
assert.match(workflow, /actions\/setup-node@[0-9a-f]{40}[^\n]*# v[0-9]+\.[0-9]+\.[0-9]+/);
assert.match(workflow, /node-version: 24\.19\.0/);
assert.match(workflow, /npm ci --ignore-scripts --no-audit/);
assert.match(pages, /node tests\/site\.test\.js/);
assert.match(pages, /__PLUGIN_VERSION__/);
assert.match(release, /group: release-\$\{\{ github\.ref \}\}/);
assert.match(dependabot, /package-ecosystem: npm/);
for (const [name, source] of [["CI", workflow], ["Pages", pages], ["Release", release]]) {
  assert.doesNotMatch(source, /runs-on: ubuntu-latest/, `${name} must use a fixed runner image`);
  assert.match(source, /runs-on: ubuntu-24\.04/);
  const checkouts = (source.match(/uses: actions\/checkout@/g) || []).length;
  const hardened = (source.match(/persist-credentials: false/g) || []).length;
  assert.equal(hardened, checkouts, `${name} checkouts must not retain credentials`);
}
console.log("validation entry-point checks passed");
