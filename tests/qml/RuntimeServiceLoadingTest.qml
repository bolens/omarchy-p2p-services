import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  property bool completed: false
  property bool advanceScheduled: false
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/loading-helper"))

  QtObject {
    id: shellMock
    function serviceFor(_id) { return null }
    function updateEntryInline(_id, _settings) {}
  }
  QtObject {
    id: barMock
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
    function switchPanelFrom(_owner, _direction) { return false }
    function requestPopout(_key) { activePopout = true }
    function releasePopout(_key) { activePopout = false }
  }
  BarWidget {
    id: widget
    bar: barMock
    helper: root.fixtureHelper
    settings: ({eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false,showLoadingIndicators:true})
  }

  function scheduleAdvance() {
    if (advanceScheduled || completed) return
    advanceScheduled = true
    Qt.callLater(root.advanceWhenReady)
  }

  function advanceWhenReady() {
    advanceScheduled = false
    if (stage === 0 && !widget.statusLoading && !widget.serviceLoadingVisible) {
      if (widget.statusLoading || widget.serviceLoadingVisible || widget.errorText !== "") throw new Error("successful discovery loading state did not settle")
      widget.adoptTransferredSettings({eventRefresh:false,privacyFilter:false,showTrafficStats:false,showLoadingIndicators:false})
      widget.services = []
      stage = 1
      widget.refresh(false, true, true)
      if (!widget.statusLoading) throw new Error("delayed failure did not enter loading state")
      if (widget.setting("showLoadingIndicators", true) !== false) throw new Error("disabled loading preference was not applied")
      if (widget.serviceLoadingVisible) throw new Error("disabled service loading indicator was rendered")
    } else if (stage === 1 && !widget.statusLoading) {
      if (widget.statusLoading || widget.errorText === "") throw new Error("failed discovery loading state did not settle")
      completed = true
      console.log("P2P_QML_SERVICE_LOADING_OK")
      Qt.quit()
    }
  }

  Connections {
    target: widget
    function onStatusLoadingChanged() { root.scheduleAdvance() }
    function onServiceLoadingVisibleChanged() { root.scheduleAdvance() }
  }

  Component.onCompleted: Qt.callLater(function() {
    widget.open()
    if (!widget.statusLoading || !widget.statusIndicatorVisible) throw new Error("delayed discovery did not retain its minimum loading state")
  })
  Timer { interval: 3000; running: !root.completed; onTriggered: { throw new Error("service loading test timed out at stage " + root.stage) } }
}
