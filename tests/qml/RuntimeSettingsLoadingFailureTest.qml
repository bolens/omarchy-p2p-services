import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/smoke-helper"))
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
    property bool vertical: false
    property int barSize: 40
    property string position: "top"
    property var screen: null
    function switchPanelFrom(_owner, _direction) { return false }
  }
  BarWidget {
    id: widget
    bar: barMock
    helper: root.fixtureHelper
    settingsSurfaceSource: Qt.resolvedUrl("tests/fixtures/does-not-exist.qml")
    settings: ({eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showLoadingIndicators:true})
  }
  Component.onCompleted: {
    widget.showingWidgetSettings = true
    if (!widget.settingsIndicatorVisible) throw new Error("failed settings load did not start presentation")
  }
  Timer {
    interval: 400
    running: true
    repeat: true
    onTriggered: {
      if (root.stage === 0) {
      if (widget.settingsIndicatorVisible || widget.visibleErrorText !== "Unable to load P2P settings interface") throw new Error("failed settings load did not terminate presentation")
      widget.showingWidgetSettings = false
      widget.settingsSurfaceSource = ""
      widget.showingWidgetSettings = true
      if (!widget.settingsIndicatorVisible) throw new Error("settings retry did not restart loading presentation")
      root.stage = 1
      } else if (root.stage === 1) {
      if (!widget.settingsSurfaceLoaded || widget.settingsIndicatorVisible || widget.settingsErrorText !== "") throw new Error("settings retry did not recover from loader failure")
      console.log("P2P_QML_SETTINGS_LOADING_FAILURE_OK")
      Qt.quit()
      }
    }
  }
}
