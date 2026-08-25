#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const markdownFiles = [];

function collect(directory) {
  for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
    if ([".git", "node_modules", "__pycache__"].includes(entry.name)) continue;
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(absolute);
    else if (entry.name.endsWith(".md")) markdownFiles.push(absolute);
  }
}

collect(root);
for (const file of markdownFiles) {
  const content = fs.readFileSync(file, "utf8");
  for (const match of content.matchAll(/!?\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = match[1].trim().replace(/^<|>$/g, "").split(/[?#]/, 1)[0];
    if (!target || /^(?:[a-z]+:|\/)/i.test(target)) continue;
    const resolved = path.resolve(path.dirname(file), decodeURIComponent(target));
    assert.ok(resolved.startsWith(root + path.sep), `${path.relative(root, file)} link escapes repository: ${target}`);
    assert.ok(fs.existsSync(resolved), `${path.relative(root, file)} has missing link: ${target}`);
  }
}

const readme = fs.readFileSync(path.join(root, "README.md"), "utf8");
assert.match(readme, /!\[P2P Services[^\]]*\]\(preview\.png(?:\?v=[0-9a-f]+)?\)/, "README must display preview.png");
assert.match(readme, /omarchy plugin add https:\/\/github\.com\/bolens\/omarchy-p2p-services\.git --enable/);
assert.ok(fs.statSync(path.join(root, "preview.png")).size > 0, "preview.png must not be empty");
assert.match(readme, /bolens\.github\.io\/omarchy-p2p-services/);
for (const image of ["compact.png", "grid.png", "general.png", "appearance.png", "services.png", "performance.png", "discovery.png", "packages.png", "bar.png"])
  assert.ok(fs.existsSync(path.join(root, "docs", image)), `missing screenshot: ${image}`);

console.log("documentation checks passed");
