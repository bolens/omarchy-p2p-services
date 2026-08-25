#!/usr/bin/env node

const assert = require("assert");
const fs = require("fs");

const manifest = JSON.parse(fs.readFileSync("manifest.json", "utf8"));
const changelog = fs.readFileSync("CHANGELOG.md", "utf8");
const release = fs.readFileSync(".github/workflows/release.yml", "utf8");
const readme = fs.readFileSync("README.md", "utf8");
const preview = fs.readFileSync("preview.png");

assert.match(manifest.version, /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/);
assert.equal(manifest.id, "io.github.bolens.p2p-services");
const escapedVersion = manifest.version.replace(/\./g, "\\.");
assert.match(changelog, new RegExp(`^## \\[${escapedVersion}\\] - \\d{4}-\\d{2}-\\d{2}$`, "m"));
assert.match(changelog, new RegExp(`^\\[Unreleased\\]: .+/compare/v${escapedVersion}\\.\\.\\.HEAD$`, "m"));
assert.ok(release.includes("tags:\n      - v*.*.*"));
assert.ok(release.includes("jq -r .version manifest.json"));
assert.match(readme, /## Installation/);
assert.match(readme, /## Removal/);
assert.match(readme, /Runtime dependencies are/);
assert.equal(preview.subarray(1, 4).toString(), "PNG");
assert.ok(preview.readUInt32BE(16) >= 500, "preview width must be at least 500px");
assert.ok(preview.readUInt32BE(20) >= 400, "preview height must be at least 400px");

console.log("release metadata tests passed");
