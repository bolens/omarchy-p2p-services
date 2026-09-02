pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property bool completed: false
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/watcher-helper"))

  Service { id: service; helper: root.fixtureHelper }

  function finishWhenReady() {
    if (completed || service.watcherCode !== "second" || service.refreshSerial !== 1) return
    completed = true
    if (service.watcherHealth !== "healthy" || service.watcherLastHeartbeatAt <= 0)
      throw new Error("watcher event state failed")
    if (service.lastFullScan !== true || service.lastDurationMs !== 2)
      throw new Error("watcher events were not debounced into one full refresh")
    console.log("P2P_QML_WATCHER_INTEGRATION_OK")
    Qt.quit()
  }

  Component.onCompleted: service.configure({eventRefresh:true,privacyFilter:true,showTrafficStats:false})

  Connections {
    target: service
    function onWatcherCodeChanged() { root.finishWhenReady() }
    function onRefreshSerialChanged() { root.finishWhenReady() }
  }

  Timer { interval: 3500; running: true; onTriggered: { throw new Error("watcher integration test timed out") } }
}
