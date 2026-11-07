const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs.readFileSync(path.join(__dirname, "..", "P2PServiceCard.qml"), "utf8")

function click(objectName) {
  const line = source.split("\n").find(line => line.includes(`objectName: "${objectName}"`))
  assert.ok(line, `${objectName} remains addressable`)
  const match = line.match(/onClicked:\s*(.+)\s*\}$/)
  assert.ok(match, `${objectName} retains its click expression`)
  return new vm.Script(match[1])
}

for (const active of [false, true]) {
  const entry = { id: "fixture-service", active }
  const events = []
  const controller = {
    act(item, action) { events.push(["action", item, action]) },
    toggleServiceDetails(id) { events.push(["details", id]) },
    editService(id) { events.push(["edit", id]) },
  }
  const poisoned = new Proxy({}, { get() { throw new Error("nested scope must not replace the card owner") } })
  const context = { card: { entry, controller }, entry: poisoned, controller: poisoned }
  click("servicePrimaryActionButton").runInNewContext(context)
  click("serviceDetailsButton").runInNewContext(context)
  click("serviceCustomizeButton").runInNewContext(context)
  assert.deepEqual(events, [["action", entry, active ? "stop" : "start"], ["details", entry.id], ["edit", entry.id]])
}

// Bound delegates must retain explicit role injection. Card entry deliberately
// stays optional because callers apply its binding after delegate construction.
assert.match(source, /^pragma ComponentBehavior: Bound\n/)
assert.equal((source.match(/required property var modelData/g) || []).length, 2)
assert.match(source, /required property var controller/)
assert.match(source, /property var entry: \(\{/)
assert.doesNotMatch(source, /required property var entry/)
console.log("service card owner contracts passed (active/stopped action and details/edit dispatch)")
