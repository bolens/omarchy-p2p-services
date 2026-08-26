#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");

const runner = fs.readFileSync("tests/run_all.sh", "utf8");
const workflow = fs.readFileSync(".github/workflows/ci.yml", "utf8");
assert.match(runner, /P2P_RUNTIME_TESTS/);
assert.match(runner, /tests\/run_qml_runtime\.sh/);
assert.match(runner, /Runtime QML tests skipped/);
assert.match(runner, /--portable/);
assert.match(workflow, /tests\/run_all\.sh --portable/);
assert.doesNotMatch(workflow, /node tests\/model\.test\.js/);
console.log("validation entry-point checks passed");
