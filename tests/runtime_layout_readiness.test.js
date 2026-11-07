const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const filter = fs.readFileSync(path.join(__dirname, 'qml/RuntimeFilterBarTest.qml'), 'utf8');
assert.ok(!filter.includes('ensurePolished'), 'real frames replace manual polish guesses');
const frameHandler = filter.match(/function onFrameSwapped\(\) \{([^]*?)\n      \}\n    \}\n    ColumnLayout/);
assert.ok(frameHandler, 'exercise actual owned-window frame guard');
const frame = new Function('root', 'narrowFilterBar', 'Qt', frameHandler[1]);
let configured = 0, verified = 0;
const callbacks = [];
const state = {frameStage: 0, constrainedWidth: 0,
  configureConstraint() { configured += 1; this.constrainedWidth = 300; },
  verifyLayoutAndActions() { verified += 1; }};
const view = {width: 400};
const Qt = {callLater(callback) { callbacks.push(callback); }};
frame(state, view, Qt);
assert.equal(configured, 1);
assert.equal(callbacks.length, 0, 'first actual frame only establishes constraint');
frame(state, view, Qt);
assert.equal(callbacks.length, 0, 'a pre-resize frame must not run assertions');
view.width = 300;
frame(state, view, Qt);
assert.equal(callbacks.length, 1, 'post-resize actual frame schedules assertions');
frame(state, view, Qt);
assert.equal(callbacks.length, 1, 'subsequent frames cannot duplicate assertions');
callbacks[0]();
assert.equal(verified, 1);
const completion = filter.match(/filterWindow\.visible = false([^]*?)Qt\.quit\(\)/);
assert.ok(completion, 'close the actual owned window before marker and quit');
const finish = new Function('filterWindow', 'console', 'Qt', completion[0]);
const completionEvents = [];
const ownedWindow = {get visible() { return this.hidden !== true; }, set visible(value) { this.hidden = !value; completionEvents.push('closed'); }};
finish(ownedWindow, {log(marker) { assert.equal(ownedWindow.visible, false); completionEvents.push(marker); }},
  {quit() { completionEvents.push('quit'); }});
assert.deepEqual(completionEvents, ['closed', 'P2P_QML_FILTER_BAR_OK', 'quit']);
assert.throws(() => finish({get visible() { return true; }, set visible(_value) {}}, {log() { throw Error('unexpected marker'); }},
  {quit() { throw Error('unexpected quit'); }}), /did not close/);
const selection = filter.match(/var widestGroup =[^]*?(?=    root\.constrainedWidth = constrainedWidth)/);
assert.ok(selection, 'exercise actual constrained-width fixture logic');
const constrained = new Function('narrowPrimary', 'narrowActions', 'Style', selection[0] + '\nreturn constrainedWidth;');
for (const [primary, actions, gap] of [[198.734375, 197.046875, 4], [300, 220, 8], [90, 410, 12], [1024, 33, 4]]) {
  const width = constrained({width: primary}, {width: actions}, {spacing: {sm: gap}});
  assert.ok(width >= primary && width >= actions, 'both groups fit separately');
  assert.ok(width < primary + actions + gap, 'the groups cannot share a row');
}
assert.throws(() => constrained({width: 0}, {width: 0}, {spacing: {sm: 0}}), /could not construct/);
for (const source of [filter, fs.readFileSync(path.join(__dirname, 'qml/RuntimeMessageSurfaceTest.qml'), 'utf8')]) {
  assert.match(source, /PanelWindow \{/);
  assert.match(source, /WlrLayershell.keyboardFocus: WlrKeyboardFocus.None/);
  assert.match(source, /contentItem.Window.window/);
  assert.ok(!source.includes('_backingWindow'));
}
const smoke = fs.readFileSync(path.join(__dirname, 'qml/RuntimePluginSmokeTest.qml'), 'utf8');
const branch = smoke.match(/else if \(root\.stage === 6\) \{([^]*?)\n      \} else if \(root\.stage === 7\)/);
assert.ok(branch, 'exercise actual stage-six state transition');
const advance = new Function('widget', 'root', branch[1]);
const root = {stage: 6, fixtureHelper: '/owned/helper'};
let requests = 0;
const widget = {catalogLoading: true, visibleErrorText: 'Service catalog refresh failed',
  serviceCatalog: [{id: 'preserved'}], refreshCatalog() { requests += 1; }};
advance(widget, root);
assert.equal(root.stage, 6);
assert.equal(requests, 0, 'an unsettled request is not restarted');
widget.catalogLoading = false;
advance(widget, root);
assert.equal(root.stage, 7);
assert.equal(requests, 1);
assert.equal(widget.helper, root.fixtureHelper);
assert.throws(() => advance({...widget, visibleErrorText: ''}, {stage: 6}), /failure was not surfaced/);
assert.throws(() => advance({...widget, serviceCatalog: []}, {stage: 6}), /replaced existing data/);
console.log('Runtime layout/readiness source contracts passed');
