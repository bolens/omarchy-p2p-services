#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const python = [read("p2p-control"), ...fs.readdirSync(path.join(root, "backend"))
  .filter(name => /^p2p_.*\.py$/.test(name))
  .map(name => read(path.join("backend", name)))].join("\n");
const qml = ["BarWidget.qml", "Service.qml", "P2PServiceCard.qml", "P2PMessageSurface.qml"]
  .map(read).join("\n");

for (const forbidden of ["shell=True", "os.system(", "subprocess.getoutput(", "subprocess.getstatusoutput("])
  if (python.includes(forbidden))
    throw new Error(`shell execution surface restored: ${forbidden}`);

if (/\bpkill\b|\bkillall\b/.test(python))
  throw new Error("broad process termination restored");
if (/\[\s*["'](?:bash|sh)["']\s*,\s*["']-c["']/.test(python))
  throw new Error("shell command construction restored");
if (!qml.includes("textFormat: Text.PlainText"))
  throw new Error("plain-text rendering boundary missing");

const workflowDirectory = path.join(root, ".github", "workflows");
for (const workflowName of fs.readdirSync(workflowDirectory)) {
  const workflow = read(path.join(".github", "workflows", workflowName));
  for (const match of workflow.matchAll(/^\s*uses:\s*([^\s#]+)(?:\s+#.*)?$/gm)) {
    const reference = match[1];
    if (reference.startsWith("./")) continue;
    if (!/@[0-9a-f]{40}$/i.test(reference))
      throw new Error(`external action is not SHA-pinned: ${workflowName}: ${reference}`);
  }
}

const ci = read(path.join(".github", "workflows", "ci.yml"));
const omarchyCheckout = ci.match(/repository:\s*basecamp\/omarchy[\s\S]*?ref:\s*([^\s#]+)/);
if (!omarchyCheckout || !/^[0-9a-f]{40}$/i.test(omarchyCheckout[1]))
  throw new Error("Omarchy validator source is not commit-pinned");

console.log("security contract tests passed");
