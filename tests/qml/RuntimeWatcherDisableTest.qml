import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/watcher-helper"))
  Service { id: service; helper: root.fixtureHelper }

  Component.onCompleted: service.configure({eventRefresh:true,privacyFilter:true,showTrafficStats:false})
  Timer {
    interval: 1300
    running: true
    onTriggered: {
      if (service.watcherLastHeartbeatAt <= 0) throw new Error("watch event was not received before disablement")
      service.configure({eventRefresh:false,privacyFilter:true,showTrafficStats:false})
    }
  }
  Timer {
    interval: 2300
    running: true
    onTriggered: {
      if (service.refreshSerial !== 0 || service.watcherHealth !== "disabled") throw new Error("pending event refresh survived disablement")
      console.log("P2P_QML_WATCHER_DISABLE_OK")
      Qt.quit()
    }
  }
}
