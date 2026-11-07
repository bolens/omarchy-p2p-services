const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const root = path.join(__dirname, "..")
const read = name => fs.readFileSync(path.join(root, name), "utf8")

function extract(source, prefix, functionPrefix = "") {
  const start = source.indexOf(prefix)
  assert.notEqual(start, -1, `missing actual source entry point ${prefix}`)
  for (let end = source.indexOf("}", start); end !== -1; end = source.indexOf("}", end + 1)) {
    try { return new vm.Script(`(${functionPrefix}${source.slice(start, end + 1)})`) }
    catch (error) { if (!(error instanceof SyntaxError)) throw error }
  }
  throw new Error(`no complete actual source body for ${prefix}`)
}

function methods(source, names, context) {
  const sandbox = vm.createContext(context)
  for (const name of names) context[name] = extract(source, `function ${name}(`).runInContext(sandbox)
  return context
}

const refreshSource = read("P2PRefreshController.qml")
assert.match(refreshSource, /component RefreshProcess: Process \{ property bool fullScan: false \}/)
assert.match(refreshSource, /property RefreshProcess process: RefreshProcess \{/)
const scheduled = []
let starts = 0
const refresh = { busy: false, timedOut: false, queuedRequest: null,
  process: { fullScan: false, running: false, command: [] },
  watchdog: { start() { starts++ } }, Qt: { callLater(fn) { scheduled.push(fn) } } }
refresh.controller = refresh
methods(refreshSource, ["request", "start", "drain"], refresh)
assert.equal(refresh.request([], true, true), false)
assert.equal(refresh.request(["fixture-helper", "status"], false, false), true)
assert.deepEqual(Array.from(refresh.process.command), ["fixture-helper", "status", "running-containers", "use-cache"])
assert.equal(refresh.request(["fixture-helper", "status"], true, false), false)
assert.equal(refresh.request(["fixture-helper", "status"], false, true), false)
assert.equal(refresh.queuedRequest.fullScan, true)
assert.equal(refresh.queuedRequest.bypassCache, true)
refresh.drain()
assert.equal(starts, 1, "queued refresh remains deferred")
assert.equal(scheduled.length, 1)
scheduled[0]()
assert.equal(starts, 2)
assert.equal(refresh.process.fullScan, true)
assert.deepEqual(Array.from(refresh.process.command), ["fixture-helper", "status", "all-containers", "bypass-cache"])

const transferSource = read("P2PSettingsTransferController.qml")
assert.match(transferSource, /component TransferProcess: Process \{ property string mode: "" \}/)
assert.match(transferSource, /property TransferProcess process: TransferProcess \{/)
const transfer = { helper: "fixture-helper", busy: false, activeMode: "", timedOut: false,
  process: { mode: "", command: [], running: false }, watchdog: { start() {} } }
methods(transferSource, ["hasHelper", "request", "refreshUndoAvailability"], transfer)
assert.equal(transfer.request("invalid"), false)
assert.equal(transfer.request("import"), true)
assert.equal(transfer.process.mode, "import")
assert.deepEqual(Array.from(transfer.process.command), ["fixture-helper", "settings-import"])
assert.equal(transfer.request("undo"), false, "busy transfer must not be replaced")
transfer.busy = false
assert.equal(transfer.refreshUndoAvailability(), true)
assert.equal(transfer.activeMode, "check")
assert.equal(transfer.process.mode, "check")
assert.deepEqual(Array.from(transfer.process.command), ["fixture-helper", "settings-can-undo"])

const model = vm.createContext({})
vm.runInContext(read("Model.js").replace(/^\.pragma library\s*$/m, ""), model)
const navigationSource = read("tests/qml/RuntimeNavigationTest.qml")
assert.match(navigationSource, /component NavigationHarness: Item \{/)
assert.match(navigationSource, /property NavigationHarness harness: NavigationHarness \{\}/)
const order = []
const viewport = { contentY: 0, height: 240, contentHeight: 0, contentItem: {} }
const navigation = { selectedIndex: -1, viewport, Model: model,
  content: { forceLayout() { order.push("layout") }, childrenRect: { height: 520 } },
  cards: { count: 5, itemAt(index) { return { height: 80, mapToItem() { return { y: 120 + index * 80 } } } } } }
methods(navigationSource, ["prepareLayout", "move"], navigation)
navigation.prepareLayout()
assert.deepEqual(order, ["layout"])
assert.equal(viewport.contentHeight, 520)
navigation.move(1)
assert.equal(navigation.selectedIndex, 0)
assert.equal(viewport.contentY, 0)
navigation.move(1)
navigation.move(1)
assert.equal(navigation.selectedIndex, 2)
assert.equal(viewport.contentY, 120)
navigation.selectedIndex = -1
viewport.contentY = 0
navigation.move(-1)
assert.equal(navigation.selectedIndex, 4)
assert.equal(viewport.contentY, 280)

for (const name of ["P2PFilterBar.qml", "P2PIndicatorPill.qml", "P2PLoadingIndicator.qml"]) {
  assert.doesNotMatch(read(name), /Style\.font\.mono/)
  assert.match(read(name), /font\.family: Style\.font\.family/)
}
console.log("typed process and navigation source contracts passed (no QML engine execution)")
