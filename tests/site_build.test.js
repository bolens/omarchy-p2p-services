#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const sourceRoot = path.join(__dirname, "..");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "p2p-site-build-"));
try {
  fs.mkdirSync(path.join(temporary, "scripts"));
  fs.mkdirSync(path.join(temporary, "docs"));
  fs.copyFileSync(path.join(sourceRoot, "scripts", "build-site.sh"), path.join(temporary, "scripts", "build-site.sh"));
  fs.chmodSync(path.join(temporary, "scripts", "build-site.sh"), 0o755);
  fs.writeFileSync(path.join(temporary, "manifest.json"), '{"version":"1.2.3"}\n');
  fs.writeFileSync(path.join(temporary, "docs", "index.html"), "<p>__PLUGIN_VERSION__</p>\n");
  fs.writeFileSync(path.join(temporary, "docs", "asset.txt"), "current\n");
  fs.mkdirSync(path.join(temporary, "_site"));
  fs.writeFileSync(path.join(temporary, "_site", "stale.txt"), "stale\n");

  const result = spawnSync(path.join(temporary, "scripts", "build-site.sh"), [], { cwd: "/", encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.existsSync(path.join(temporary, "_site", "stale.txt")), false, "stale output survived rebuild");
  assert.equal(fs.readFileSync(path.join(temporary, "_site", "manifest.json"), "utf8"), '{"version":"1.2.3"}\n');
  assert.equal(fs.readFileSync(path.join(temporary, "_site", "asset.txt"), "utf8"), "current\n");
  const builtHtml = fs.readFileSync(path.join(temporary, "_site", "index.html"), "utf8");
  assert.match(builtHtml, /1\.2\.3/);
  assert.doesNotMatch(builtHtml, /__PLUGIN_VERSION__/);
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}

console.log("site build tests passed");
