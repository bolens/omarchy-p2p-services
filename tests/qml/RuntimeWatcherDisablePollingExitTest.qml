import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property bool disabled: false
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/watcher-polling-exit-helper"))
  Service { id: service; helper: root.fixtureHelper }

  Component.onCompleted: service.configure({eventRefresh:true})
  Connections {
    target: service
    function onWatcherLastHeartbeatAtChanged() {
      if (root.disabled || service.watcherLastHeartbeatAt <= 0) return
      root.disabled = true
      service.configure({eventRefresh:false})
      verification.start()
    }
  }
  Timer {
    id: verification
    interval: 500
    onTriggered: {
      if (service.watcherHealth !== "disabled" || service.watcherCode !== "disabled" || service.watcherPollingOnly)
        throw new Error("polling-only exit overwrote disabled watcher state: " + service.watcherHealth + "/" + service.watcherCode + "/" + service.watcherPollingOnly)
      console.log("P2P_QML_WATCHER_DISABLE_POLLING_EXIT_OK")
      Qt.quit()
    }
  }
  Timer { interval: 3000; running: !root.disabled; onTriggered: { throw new Error("watcher disable polling-exit test timed out") } }
}
