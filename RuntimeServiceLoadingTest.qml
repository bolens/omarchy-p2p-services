import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
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
    settings: ({eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false,showLoadingIndicators:true})
  }

  Timer {
    interval: 100
    running: true
    onTriggered: if (!widget.statusLoading || !widget.serviceLoadingVisible) throw new Error("delayed discovery did not render loading state")
  }
  Timer {
    interval: 550
    running: true
    onTriggered: {
      if (widget.statusLoading || widget.serviceLoadingVisible || widget.errorText !== "") throw new Error("successful discovery loading state did not settle")
      widget.adoptTransferredSettings({eventRefresh:false,privacyFilter:false,showTrafficStats:false,showLoadingIndicators:false})
      widget.services = []
      widget.refresh(false, true, true)
    }
  }
  Timer {
    interval: 650
    running: true
    onTriggered: {
      if (!widget.statusLoading) throw new Error("delayed failure did not enter loading state")
      if (widget.setting("showLoadingIndicators", true) !== false) throw new Error("disabled loading preference was not applied")
      if (widget.serviceLoadingVisible) throw new Error("disabled service loading indicator was rendered")
    }
  }
  Timer {
    interval: 1050
    running: true
    onTriggered: {
      if (widget.statusLoading || widget.errorText === "") throw new Error("failed discovery loading state did not settle")
      console.log("P2P_QML_SERVICE_LOADING_OK")
      Qt.quit()
    }
  }
}
