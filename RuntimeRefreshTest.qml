import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var scans: []
  property int completions: 0
  readonly property var command: ["/usr/bin/sh", "-c", "sleep 0.05; printf refresh-ok", "p2p-refresh-test"]

  property P2PRefreshController refreshController: P2PRefreshController {
    onSucceeded: function(payload, fullScan) {
      root.scans = root.scans.concat([fullScan])
      root.completions += 1
      if (payload !== "refresh-ok") throw new Error("refresh payload collection failed")
      if (root.completions === 2) {
        if (root.scans.length !== 2 || root.scans[0] !== false || root.scans[1] !== true)
          throw new Error("queued full scan was not preserved")
        console.log("P2P_QML_REFRESH_OK")
        Qt.quit()
      }
    }
    onFailed: function(exitCode, fullScan) { throw new Error("refresh command failed: " + exitCode + ", fullScan=" + fullScan) }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("refresh queue test timed out") }
  }

  Component.onCompleted: {
    if (!refreshController.request(command, false, false)) throw new Error("initial refresh did not start")
    if (refreshController.request(command, true, true)) throw new Error("concurrent refresh was not queued")
    if (!refreshController.queuedRequest || !refreshController.queuedRequest.fullScan || !refreshController.queuedRequest.bypassCache)
      throw new Error("queued refresh flags were lost")
  }
}
