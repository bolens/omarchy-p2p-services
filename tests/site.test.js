#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "docs/index.html"), "utf8");

function dimensions(name) {
  const image = fs.readFileSync(path.join(root, "docs", name));
  assert.deepEqual([...image.subarray(0, 8)], [137,80,78,71,13,10,26,10], `${name} must be PNG`);
  return [image.readUInt32BE(16), image.readUInt32BE(20)];
}

assert.match(html, /<main id="main">/);
assert.match(html, /prefers-reduced-motion/);
assert.match(html, /bolens\/omarchy-p2p-services/);
assert.match(html, /__PLUGIN_VERSION__/);
assert.match(html, /privacy filter is forced on/i);
assert.doesNotMatch(html, /omarchy-privacy-devices/);
assert.equal((html.match(/<div class="showcase" data-showcase>/g) || []).length, 2);
assert.equal((html.match(/role="tablist"/g) || []).length, 2);
assert.equal((html.match(/<button class="tab" role="tab"/g) || []).length, 9);
assert.match(html, /ArrowLeft/);
assert.match(html, /aria-selected/);
for (const image of ["panel.png", "compact.png", "grid.png", "general.png", "appearance.png", "services.png", "performance.png", "discovery.png", "packages.png", "bar.png"]) {
  const [width, height] = dimensions(image);
  assert.ok(width > 0 && height > 0, `${image} must not be empty`);
  assert.match(html, new RegExp(`src="${image.replace(".", "\\.")}"`));
}
assert.deepEqual(dimensions("preview.png"), dimensions("panel.png"));
const capture = fs.readFileSync(path.join(root, "scripts/capture-screenshots"), "utf8");
for (const safeguard of ["flock -n", "trap restore_desktop", "settings-patch", "privacyEnabled", "status private", "-strip", "window_count", "sha256sum"])
  assert.ok(capture.includes(safeguard), `capture workflow is missing safeguard: ${safeguard}`);
assert.match(capture, /privacyFilter[\\"]*:?[\\"]*true/);
assert.match(capture, /for page in general appearance services performance discovery packages/);
assert.match(capture, /update-screenshot-metadata/);
console.log("site checks passed");
