const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

// Exercise the actual JavaScript callback bodies without launching QML helpers.
function handler(file, index = 0) {
  const source = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
  const matches = [...source.matchAll(/onExited:\s*(function\(exitCode\)\s*\{)/g)]
  assert.ok(matches[index], `${file} must retain its exit-code callback`)
  const start = matches[index].index + matches[index][0].indexOf("function")
  for (let end = source.indexOf("}", start); end !== -1; end = source.indexOf("}", end + 1)) {
    try {
      return new vm.Script(`(${source.slice(start, end + 1)})`, { filename: file })
    } catch (error) {
      if (!(error instanceof SyntaxError)) throw error
    }
  }
  throw new Error(`${file} has no complete exit callback`)
}

const cases = [
  ["P2PActionRunner.qml", 0, "runner", "watchdog", "action"],
  ["P2PCatalogController.qml", 0, "controller", "watchdog", "catalog"],
  ["P2PEventJournal.qml", 0, "journal", "watchdog", "events"],
  ["P2PRefreshController.qml", 0, "controller", "watchdog", "refresh"],
  ["P2PSettingsStore.qml", 0, "store", "loadWatchdog", "load"],
  ["P2PSettingsStore.qml", 1, "store", "saveWatchdog", "save"],
  ["P2PSettingsTransferController.qml", 0, "controller", "watchdog", "transfer"],
]

for (const [file, index, ownerName, watchdogName, kind] of cases) {
  const callback = handler(file, index)
  for (const result of ["success", "failure", "timeout"]) {
    const events = []
    const scheduled = []
    const entry = { id: "fixture" }
    const owner = {
      busy: true, pending: false, timedOut: result === "timeout",
      activeEntry: entry, activeAction: "restart", activeMode: "import",
      moduleName: "fixture-module", loadBusy: true, loaded: false,
      loadTimedOut: result === "timeout", saveTimedOut: result === "timeout",
      loadFallback: { fallback: true }, activeSaveFallback: { fallback: true },
      queuedSettings: null, durableSettings: { original: true },
    }
    owner[watchdogName] = { stop() { events.push(["stop"]) } }
    for (const name of ["actionFinished", "updated", "failed", "succeeded", "drain", "loadFailed", "reconciled", "saveFailed", "saved"])
      owner[name] = (...args) => events.push([name, ...args])
    owner.startNext = () => { throw new Error("next queued command must remain deferred") }
    owner.process = { fullScan: true, mode: "import", command: ["fixture-helper", "events"] }
    const shadow = { stop() { throw new Error("nested scope must not replace the outer watchdog") } }
    const context = {
      [ownerName]: owner, watchdog: shadow, loadWatchdog: shadow, saveWatchdog: shadow,
      errorOutput: { text: " detail " }, output: { text: " [] " },
      loadOutput: { text: '{"value":true,"id":"untrusted"}' }, saveOutput: { text: "{}" },
      process: new Proxy({}, { get() { throw new Error("nested process must not replace the owner's process") } }),
      patchMode: false, Model: { parseCatalog: () => [{ id: "catalog-fixture" }] },
      Qt: { callLater(fn) { scheduled.push(fn) } },
    }
    const exitCode = result === "failure" ? 9 : 0
    callback.runInNewContext(context)(exitCode)
    assert.deepEqual(events[0], ["stop"], `${file}/${kind}/${result} must disarm its owner first`)
    assert.equal(events.filter(event => event[0] === "stop").length, 1)
    const effective = result === "timeout" ? -2 : exitCode
    const has = name => events.some(event => event[0] === name)
    const event = name => events.find(event => event[0] === name)
    if (kind === "action") {
      assert.equal(owner.busy, false)
      assert.equal(owner.activeEntry, null)
      assert.equal(owner.activeAction, "")
      assert.equal(event("actionFinished")[1], entry)
      assert.deepEqual(event("actionFinished").slice(2), ["restart", effective, result === "timeout" ? "Operation timed out" : "detail"])
    } else if (kind === "catalog") {
      assert.equal(owner.busy, false)
      assert.equal(has("updated"), result === "success")
      if (result !== "success") assert.equal(event("failed")[1], effective)
    } else if (kind === "events") {
      assert.equal(owner.busy, false)
      assert.equal(has("failed"), result !== "success")
      assert.equal(scheduled.length, 1)
      assert.equal(scheduled[0], owner.startNext)
    } else if (kind === "refresh") {
      assert.equal(events.at(-1)[0], "drain")
      assert.deepEqual(result === "success" ? event("succeeded").slice(1) : event("failed").slice(1),
        result === "success" ? ["[]", true] : [effective, true])
    } else if (kind === "load") {
      assert.equal(owner.loadBusy, false)
      assert.equal(owner.loaded, true)
      assert.equal(has("loadFailed"), result !== "success")
      assert.equal(owner.durableSettings.id, "fixture-module")
      assert.equal(result === "success" ? owner.durableSettings.value : owner.durableSettings.fallback, true)
      assert.equal(events.at(-1)[0], "reconciled")
    } else if (kind === "save") {
      assert.equal(owner.busy, false)
      assert.equal(has("saveFailed"), result !== "success")
      assert.equal(has("saved"), result === "success")
      if (result !== "success") assert.equal(owner.durableSettings.fallback, true)
    } else if (kind === "transfer") {
      assert.equal(owner.busy, false)
      assert.equal(owner.activeMode, "")
      if (result === "success") {
        assert.equal(owner.undoAvailable, true)
        assert.deepEqual(event("succeeded").slice(1), ["import", "[]"])
      } else assert.deepEqual(event("failed").slice(1), ["import", effective, result === "timeout" ? "Operation timed out" : "detail"])
    }
  }
}
console.log("process exit ownership contracts passed (7 callbacks, success/failure/timeout)")
