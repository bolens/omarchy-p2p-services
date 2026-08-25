import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/polling-helper"))

  Service { id: service; helper: root.fixtureHelper }

  Component.onCompleted: service.configure({eventRefresh:true})
  Timer {
    interval: 1400
    running: true
    onTriggered: {
      if (service.watcherHealth !== "polling" || service.watcherCode !== "polling-only" || !service.watcherPollingOnly)
        throw new Error("unsupported watcher did not settle into polling mode")
      console.log("P2P_QML_WATCHER_POLLING_OK")
      Qt.quit()
    }
  }
}
