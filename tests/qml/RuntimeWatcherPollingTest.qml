import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property bool completed: false
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/polling-helper"))

  Service { id: service; helper: root.fixtureHelper }

  function finishWhenReady() {
    if (completed || service.watcherHealth !== "polling" || service.watcherCode !== "polling-only" || !service.watcherPollingOnly) return
    completed = true
    console.log("P2P_QML_WATCHER_POLLING_OK")
    Qt.quit()
  }

  Component.onCompleted: service.configure({eventRefresh:true})
  Connections {
    target: service
    function onWatcherHealthChanged() { root.finishWhenReady() }
    function onWatcherCodeChanged() { root.finishWhenReady() }
    function onWatcherPollingOnlyChanged() { root.finishWhenReady() }
  }
  Timer { interval: 3000; running: true; onTriggered: { throw new Error("unsupported watcher did not settle into polling mode") } }
}
