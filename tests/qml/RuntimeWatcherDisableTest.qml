import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property bool disabled: false
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/watcher-helper"))
  Service { id: service; helper: root.fixtureHelper }

  Component.onCompleted: service.configure({eventRefresh:true,privacyFilter:true,showTrafficStats:false})
  Connections {
    target: service
    function onWatcherLastHeartbeatAtChanged() {
      if (root.disabled || service.watcherLastHeartbeatAt <= 0) return
      root.disabled = true
      Qt.callLater(function() {
        service.configure({eventRefresh:false,privacyFilter:true,showTrafficStats:false})
        cancellationCheck.start()
      })
    }
  }
  Timer {
    id: cancellationCheck
    interval: 900
    onTriggered: {
      if (service.refreshSerial !== 0 || service.watcherHealth !== "disabled") throw new Error("pending event refresh survived disablement")
      console.log("P2P_QML_WATCHER_DISABLE_OK")
      Qt.quit()
    }
  }
  Timer { interval: 3000; running: !root.disabled; onTriggered: { throw new Error("watch event was not received before disablement") } }
}
