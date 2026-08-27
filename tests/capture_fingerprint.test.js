#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");

const root = path.resolve(__dirname, "..");
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "p2p-fingerprint-"));
fs.mkdirSync(path.join(fixture, "backend"));
fs.mkdirSync(path.join(fixture, "tests", "qml"), {recursive: true});
fs.writeFileSync(path.join(fixture, "manifest.json"), "{}");
fs.writeFileSync(path.join(fixture, "Widget.qml"), "Item {}\n");
fs.writeFileSync(path.join(fixture, "backend", "p2p_runtime.py"), "VALUE = 1\n");
fs.writeFileSync(path.join(fixture, "tests", "qml", "RuntimeTest.qml"), "Item {}\n");

function fingerprint() {
  const result = spawnSync(path.join(root, "scripts", "capture-plugin-fingerprint"), [fixture], {encoding: "utf8"});
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}

const initial = fingerprint();
fs.writeFileSync(path.join(fixture, "backend", "p2p_runtime.py"), "VALUE = 2\n");
const backendChanged = fingerprint();
assert.notEqual(backendChanged, initial, "backend runtime changes must invalidate captures");
fs.writeFileSync(path.join(fixture, "tests", "qml", "RuntimeTest.qml"), "Item { property bool changed: true }\n");
assert.equal(fingerprint(), backendChanged, "development-only harnesses must not invalidate captures");

fs.rmSync(fixture, {recursive: true});
console.log("capture fingerprint tests passed");
