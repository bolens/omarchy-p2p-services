pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window as Windowing
import Quickshell
import Quickshell.Io
import "PathUtils.js" as PathUtils

ShellRoot {
    id: root
    readonly property string configPath: Quickshell.shellPath("RuntimeIpcTransportTest.qml")
    readonly property string executable: String(Quickshell.env("QUICKSHELL_BIN") || "/usr/bin/quickshell")
    property bool announced: false
    property bool started: false
    property bool finished: false
    property int step: 0
    property BarWidget widget: null
    property BarWidget widgetB: null
    property BarWidget focusedWidget: null
    property QtObject stableHandler: null
    property bool disposalAStarted: false
    property bool disposalBStarted: false
    property bool disposedA: false
    property bool disposedB: false
    property string focusMode: "valid"
    property BarFacade barMock: null
    property BarFacade barMockB: null
    readonly property string targetName: "io.github.bolens.p2p-services"
    readonly property string requiredSignature: "function openSettings(page: string): string"
    readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/ipc-transport-helper"))
    readonly property var calls: [
        {show:true}, {method:"captureContract",args:[],expected:"2"},
        {method:"privacyEnabled",args:[],expected:"true"},
        {method:"panelClosed",args:[],expected:"true"},
        {method:"settingsSnapshot",args:[],validator:"settings"},
        {method:"openSettings",args:["__invalid_page__"],expected:"invalid page"},
        {method:"scrollSettings",args:["__invalid_position__"],expected:"invalid position"},
        {method:"__ci_missing__",args:[],code:0,expected:"Function not found."},
        {method:"captureContract",args:["extra"],code:0,
            expected:'Too many arguments provided (0 required but 1 were provided.)\nFunction definition: function captureContract(): string'},
        {method:"panelClosed",args:[],expected:"true"},
        {method:"open",args:[],expected:"unavailable",setup:"missing-focus",noAction:true},
        {method:"open",args:[],expected:"unavailable",setup:"foreign-focus",noAction:true},
        {method:"open",args:[],expected:"unavailable",setup:"ambiguous-focus",noAction:true},
        {method:"privacyEnabled",args:[],expected:"true",setup:"restore-focus"},
        {method:"privacyEnabled",args:[],expected:"false",setup:"focus-b"},
        {show:true},
        {method:"privacyEnabled",args:[],expected:"true",setup:"focus-a"},
        {method:"privacyEnabled",args:[],expected:"false",setup:"dispose-a"},
        {show:true},
        {method:"captureContract",args:[],expected:"2"},
        {show:true,empty:true,setup:"dispose-b"}
    ]
    QtObject {
        id: sharedMock
        readonly property P2PIpcHub ipcHub: P2PIpcHub { serviceIdentity: sharedMock }
        property int durableSettingsRevision: 0
        property int refreshSerial: 0
        property var services: []
        property var diagnostics: []
        property bool lastFullScan: true
        property int lastDurationMs: 0
        property string refreshError: ""
        property int requests: 0
        function configure(value) { root.assertThat(value.eventRefresh === false, "watcher was enabled") }
        function requestRefresh(fullScan, _bypassCache) { requests += 1; lastFullScan = fullScan; refreshSerial += 1 }
        function monitoringTelemetry() { return {watcherHealth:"disabled",watcherCode:"disabled",watcherRunning:false,watcherHeartbeatAgeSeconds:-1,watcherRetryMilliseconds:0,settingsWatcherHealth:"disabled",settingsWatcherCode:"disabled",settingsWatcherRunning:false,settingsWatcherLastEventAgeSeconds:-1,settingsWatcherLastExitCode:0,settingsWatcherRetryMilliseconds:0,lastRefreshAgeSeconds:0,lastDurationMs:0,diagnostics:0} }
    }
    QtObject {
        id: shellMock
        property var projections: []
        function serviceFor(id) { root.assertThat(id === root.targetName, "wrong shared service"); return sharedMock }
        function updateEntryInline(id, entry) {
            root.assertThat(id === root.targetName && projections.length < 2, "unexpected settings mutation")
            projections = projections.concat([JSON.parse(JSON.stringify(entry))])
        }
    }
    component BarFacade: QtObject {
        property string fixtureRole: "A"
        property int uiRequests: 0
        property var shell: shellMock
        property color barForeground: "#ffffff"
        property color foreground: "#ffffff"
        property color urgent: "#ff5555"
        property string fontFamily: "monospace"
        property bool foregroundAnimationEnabled: false
        property bool activePopout: false
        property bool vertical: false
        property int barSize: 40
        property string position: "top"
        property var screen: null
        function findPanelWidget(id) {
            if (id !== root.targetName || root.focusMode === "missing") return null
            if (root.focusMode === "foreign") return foreignWidget
            if (root.focusMode === "ambiguous") return fixtureRole === "A" ? root.widget : root.widgetB
            return root.focusedWidget
        }
        function moduleWidgets(id) { return id === root.targetName ? [root.widget,root.widgetB].filter(function(item) { return item !== null }) : [] }
        function switchPanelFrom(_owner, _direction) { throw new Error("read-only IPC case attempted UI control") }
        function requestPopout(_key) { uiRequests += 1; throw new Error("read-only IPC case opened a panel") }
        function releasePopout(_key) { activePopout = false }
    }
    Component { id: barFactory; BarFacade {} }
    Windowing.Window {
        visible: false
        width: 80
        height: 40
        Item { id: memberRoot; anchors.fill: parent }
    }
    QtObject { id: foreignWidget; property string moduleName: root.targetName; property QtObject p2pService: sharedMock }

    Component {
        id: memberFactory
        BarWidget {
            property string fixtureName: ""
            bar: root.barMock
            helper: root.fixtureHelper
            settings: ({privacyFilter:true,eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false})
            Component.onDestruction: root.memberDisposed(fixtureName)
        }
    }
    function fixtureReady() {
        return root.widget && root.widgetB && root.widget.durableSettingsLoaded && root.widgetB.durableSettingsLoaded
            && !root.widget.settingsStoreController.loading && !root.widgetB.settingsStoreController.loading
            && sharedMock.requests > 0 && root.widget.p2pService === sharedMock && root.widgetB.p2pService === sharedMock
            && sharedMock.ipcHub.widgetCount === 2
    }
    function memberDisposed(name) {
        if (name === "A") root.disposedA = true
        else if (name === "B") root.disposedB = true
        Qt.callLater(root.next)
    }
    function prepareStep(call) {
        root.assertThat(sharedMock.ipcHub.handler === root.stableHandler, "IPC handler identity changed during routing/handoff")
        if (call.setup === "missing-focus") root.focusMode = "missing"
        if (call.setup === "foreign-focus") root.focusMode = "foreign"
        if (call.setup === "ambiguous-focus") root.focusMode = "ambiguous"
        if (call.setup === "restore-focus") { root.focusMode = "valid"; root.focusedWidget = root.widget }
        if (call.setup === "focus-b") root.focusedWidget = root.widgetB
        if (call.setup === "focus-a") root.focusedWidget = root.widget
        if (call.setup === "dispose-a") {
            if (!root.disposalAStarted) {
                root.disposalAStarted = true
                root.focusedWidget = root.widgetB
                root.assertMemberClean(root.widget)
                root.widget.destroy()
                root.widget = null
            }
            return root.disposedA && sharedMock.ipcHub.widgetCount === 1
        }
        if (call.setup === "dispose-b") {
            if (!root.disposalBStarted) {
                root.disposalBStarted = true
                root.focusedWidget = null
                root.assertMemberClean(root.widgetB)
                root.widgetB.destroy()
                root.widgetB = null
            }
            return root.disposedB && sharedMock.ipcHub.widgetCount === 0
        }
        return true
    }
    function assertMemberClean(member) {
        root.assertThat(member && !member.opened && !member.settingsStoreController.busy
            && member.settingsStoreController.loaded && member.errorText === "", "member disposal changed action/UI/helper state")
    }
    function validateValue(kind, response) {
        root.assertThat(kind === "settings", "unknown validator")
        const settings = JSON.parse(response)
        root.assertThat(settings.id === root.targetName && settings.privacyFilter === true
            && settings.eventRefresh === false && settings.refreshOnOpen === false
            && settings.refreshAfterSettings === false && settings.showTrafficStats === false, "settings projection")
    }
    function finalState() {
        root.assertThat(root.disposedA && root.disposedB && sharedMock.ipcHub.widgetCount === 0
            && sharedMock.ipcHub.handler === root.stableHandler && !root.barMock.activePopout && !root.barMockB.activePopout, "owner/last-member lifecycle failed")
        root.assertThat(shellMock.projections.length === 2
            && shellMock.projections.every(function(entry) { return entry.id === root.targetName && entry.eventRefresh === false }), "unexpected settings mutation")
    }
    Connections {
        target: root.widget
        function onDurableSettingsLoadedChanged() { Qt.callLater(root.announceReady) }
    }
    Connections {
        target: root.widgetB
        function onDurableSettingsLoadedChanged() { Qt.callLater(root.announceReady) }
    }
    Connections {
        target: sharedMock.ipcHub
        function onWidgetCountChanged() {
            if (!root.started) Qt.callLater(root.announceReady)
            else if (!ipc.running && (root.disposalAStarted || root.disposalBStarted)) Qt.callLater(root.next)
        }
    }
    Connections {
        target: sharedMock
        function onRefreshSerialChanged() { Qt.callLater(root.announceReady) }
    }

    function assertThat(ok, message) {
        if (!ok) throw new Error("IPC transport contract: " + message)
    }
    function announceReady() {
        if (root.announced || !root.fixtureReady()) return
        root.widget.privacyFilterOverride = true
        root.widgetB.privacyFilterOverride = false
        root.focusedWidget = root.widget
        root.stableHandler = sharedMock.ipcHub.handler
        root.announced = true
        console.log("QML_CI_BOOTSTRAP_READY")
    }
    function startBootstrap() {
        if (!root.announced) return "not ready"
        if (root.started) return "already started"
        root.started = true
        Qt.callLater(root.next)
        return "started"
    }
    function next() {
        if (!root.started || root.finished || ipc.running) return
        if (root.step === root.calls.length) {
            root.finalState()
            root.finished = true
            console.log("P2P_QML_IPC_TRANSPORT_OK")
            Qt.quit()
            return
        }
        const call = root.calls[root.step]
        if (!root.prepareStep(call)) return
        const prefix = [root.executable, "ipc", "--no-color", "--pid", String(Quickshell.processId)]
        ipc.command = call.show === true ? prefix.concat(["show"])
            : prefix.concat(["call", root.targetName, call.method]).concat(call.args)
        ipc.running = true
    }
    function acceptResponse(call, code, stdoutText, stderrText) {
        root.assertThat(stdoutText.length <= 65536 && stderrText.length <= 65536, "oversized child output")
        const observation = JSON.stringify({step:root.step,method:call.show === true ? "show" : call.method,
            code:code,stdout:stdoutText,stderr:stderrText})
        console.log("IPC_TRANSPORT_REPLY_JSON " + observation)
        root.assertThat(stderrText === "", "unexpected child stderr: " + observation)
        root.assertThat(code === (call.code === undefined ? 0 : call.code), "wrong child exit status: " + observation)
        if (call.show === true) {
            const targets = stdoutText.split("\n").filter(function(line) { return line.indexOf("target ") === 0 }).sort()
            root.assertThat(JSON.stringify(targets) === JSON.stringify((call.empty === true ? ["target qml-ci-bootstrap"] : ["target qml-ci-bootstrap", "target " + root.targetName]).sort()), "wrong instance handler census")
            if (call.empty !== true) root.assertThat(stdoutText.indexOf(root.requiredSignature) >= 0, "missing real typed signature")
        } else if (call.validator) root.validateValue(call.validator, stdoutText)
        else root.assertThat(stdoutText === call.expected, "wrong response for " + call.method)
        if (call.noAction === true) root.assertThat(!root.widget.opened && !root.widgetB.opened
            && root.barMock.uiRequests === 0 && root.barMockB.uiRequests === 0, "unresolved focus performed an action")
    }
    IpcHandler {
        target: "qml-ci-bootstrap"
        function start(): string { return root.startBootstrap() }
    }
    Process {
        id: ipc
        stdout: StdioCollector { id: ipcOutput; waitForEnd: true }
        stderr: StdioCollector { id: ipcErrors; waitForEnd: true }
        onExited: function(code) {
            root.acceptResponse(root.calls[root.step], code, String(ipcOutput.text || "").trim(), String(ipcErrors.text || "").trim())
            root.step += 1
            Qt.callLater(root.next)
        }
    }
    Component.onCompleted: {
        // B is constructed FIRST, while explicit focus starts at A. The result
        // must not depend on construction order or which widget claimed IPC.
        root.barMock = barFactory.createObject(root, {fixtureRole:"A"})
        root.barMockB = barFactory.createObject(root, {fixtureRole:"B"})
        root.assertThat(root.barMock && root.barMockB, "host facade construction failed")
        root.widgetB = memberFactory.createObject(memberRoot, {fixtureName:"B",bar:root.barMockB})
        root.widget = memberFactory.createObject(memberRoot, {fixtureName:"A"})
        root.assertThat(root.widget && root.widgetB, "member construction failed")
        Qt.callLater(root.announceReady)
    }
    Timer {
        interval: 4000
        running: !root.finished
        repeat: false
        onTriggered: { throw new Error("IPC transport fixture deadline at step " + root.step) }
    }
}
