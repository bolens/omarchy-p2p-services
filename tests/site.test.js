#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "docs/index.html"), "utf8");
const notFound = fs.readFileSync(path.join(root, "docs/404.html"), "utf8");
const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map(match => match[1]);
assert.equal(new Set(ids).size, ids.length, "site element IDs must be unique");
for (const match of html.matchAll(/href="#([^"]+)"/g))
  assert.ok(ids.includes(match[1]), `site link targets missing #${match[1]}`);

function dimensions(name) {
  const image = fs.readFileSync(path.join(root, "docs", name));
  assert.deepEqual([...image.subarray(0, 8)], [137,80,78,71,13,10,26,10], `${name} must be PNG`);
  return [image.readUInt32BE(16), image.readUInt32BE(20)];
}

assert.match(html, /<main id="main">/);
assert.match(html, /rel="canonical" href="https:\/\/bolens\.github\.io\/omarchy-p2p-services\/"/);
assert.match(html, /name="twitter:card" content="summary_large_image"/);
assert.match(html, /type="application\/ld\+json"/);
assert.match(html, /"softwareVersion":"__PLUGIN_VERSION__"/);
assert.match(html, /prefers-reduced-motion/);
assert.match(html, /bolens\/omarchy-p2p-services/);
assert.match(html, /__PLUGIN_VERSION__/);
assert.match(html, /privacy filter is forced on/i);
assert.doesNotMatch(html, /omarchy-privacy-devices/);
for (const section of ["guide", "usage", "configuration", "services", "privacy", "performance", "troubleshooting", "removal"])
  assert.match(html, new RegExp(`id="${section}"`), `user guide is missing #${section}`);
assert.match(html, /omarchy plugin remove io\.github\.bolens\.p2p-services/);
assert.match(html, /\$XDG_STATE_HOME/);
assert.equal((html.match(/<img /g) || []).length, (html.match(/loading="lazy" decoding="async"/g) || []).length);
for (const tabContract of ["aria-controls", "aria-labelledby", "tabIndex", "history.replaceState", "location.hash"])
  assert.ok(html.includes(tabContract), `accessible tabs are missing ${tabContract}`);
assert.match(notFound, /<html lang="en">/);
assert.match(notFound, /name="robots" content="noindex"/);
assert.equal((html.match(/<div class="showcase" data-showcase>/g) || []).length, 2);
assert.equal((html.match(/role="tablist"/g) || []).length, 2);
assert.equal((html.match(/<button class="tab" role="tab"/g) || []).length, 11);
assert.match(html, /ArrowLeft/);
assert.match(html, /aria-selected/);
for (const image of ["panel.png", "details.png", "editor.png", "compact.png", "grid.png", "general.png", "appearance.png", "services.png", "performance.png", "discovery.png", "packages.png", "bar.png"]) {
  const [width, height] = dimensions(image);
  assert.ok(width > 0 && height > 0, `${image} must not be empty`);
  assert.match(html, new RegExp(`src="${image.replace(".", "\\.")}"`));
}
assert.deepEqual(dimensions("preview.png"), dimensions("panel.png"));
assert.deepEqual(dimensions("social-card.png"), [1200, 630]);
assert.match(html, /og:image" content="https:\/\/bolens\.github\.io\/omarchy-p2p-services\/social-card\.png"/);
assert.match(html, /twitter:image" content="https:\/\/bolens\.github\.io\/omarchy-p2p-services\/social-card\.png"/);
const capture = fs.readFileSync(path.join(root, "scripts/capture-screenshots"), "utf8");
for (const safeguard of ["flock -n", "trap cleanup_capture", "settings-patch", "privacyEnabled", "status private", "-strip", "window_count", "sha256sum", "Duplicate captures", "social-card.png", "restore_cursor", "validate_capture", "captureContract", "verify-capture-postconditions", "capture-environment-guard", "select-capture-monitor"])
  assert.ok(capture.includes(safeguard), `capture workflow is missing safeguard: ${safeguard}`);
assert.match(capture, /privacyFilter[\\"]*:?[\\"]*true/);
assert.match(capture, /for page in general appearance services performance discovery packages/);
assert.match(capture, /panel_width < 420 \|\| panel_width > 800/, "capture width audit must enforce the supported popup range");
assert.match(capture, /audit-\$\{page\}-top/);
assert.match(capture, /audit-\$\{page\}-bottom/);
assert.match(capture, /audit-appearance-conditional-bottom/);
assert.match(capture, /audit-services-ungrouped-bottom/);
assert.match(capture, /audit-bar-category-active-total/);
assert.match(capture, /audit-bar-category-active-nonzero/);
assert.match(capture, /capture_audit_bar/);
assert.match(capture, /audit_dir == \/tmp\//, "retained visual evidence must stay in temporary storage");
assert.match(capture, /refresh_capture_geometry/);
assert.match(capture, /wait_for_capture_geometry/);
assert.match(capture, /stable >= 2/);
assert.match(capture, /_monitorExtent/);
assert.match(capture, /open_settings_page\(\)[\s\S]*focus_capture_workspace[\s\S]*openSettings/);
assert.match(capture, /collapsedServiceGroups\\\":\{\}/,
  "visual capture must not inherit hidden service groups from user settings");
assert.match(capture, /restored_workspace == "\$original_workspace"/);
assert.match(capture, /\*\-full\.png/, "retained audit evidence must exclude full-monitor captures");
assert.match(capture, /update-screenshot-metadata/);
assert.doesNotMatch(capture, /\bsleep\s+(?:1|2)\b/, "capture workflow must wait on observable IPC state, not fixed delays");
for (const readiness of ["mainReady", "detailsReady", "editorReady", "panelClosed"])
  assert.ok(capture.includes(readiness), `capture workflow is missing readiness probe: ${readiness}`);
console.log("site checks passed");
