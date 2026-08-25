import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/watcher-helper"))

  Service { id: service; helper: root.fixtureHelper }

  Component.onCompleted: service.configure({eventRefresh:true,privacyFilter:true,showTrafficStats:false})

  Timer {
    interval: 2600
    running: true
    onTriggered: {
      if (service.watcherHealth !== "healthy" || service.watcherCode !== "second" || service.watcherLastHeartbeatAt <= 0)
        throw new Error("watcher event state failed")
      if (service.refreshSerial !== 1 || service.lastFullScan !== true || service.lastDurationMs !== 2)
        throw new Error("watcher events were not debounced into one full refresh")
      console.log("P2P_QML_WATCHER_INTEGRATION_OK")
      Qt.quit()
    }
  }

  Timer { interval: 3500; running: true; onTriggered: { throw new Error("watcher integration test timed out") } }
}
