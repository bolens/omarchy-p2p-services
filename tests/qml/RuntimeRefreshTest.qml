pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var scans: []
  property var payloads: []
  property int completions: 0
  readonly property var initialCommand: ["/usr/bin/sh", "-c", "sleep 0.05; printf initial", "p2p-refresh-test"]
  readonly property var staleCommand: ["/usr/bin/sh", "-c", "printf stale", "p2p-refresh-test"]
  readonly property var latestCommand: ["/usr/bin/sh", "-c", "printf latest", "p2p-refresh-test"]

  property P2PRefreshController refreshController: P2PRefreshController {
    onSucceeded: function(payload, fullScan) {
      root.scans = root.scans.concat([fullScan])
      root.payloads = root.payloads.concat([payload])
      root.completions += 1
      if (root.completions === 2) {
        if (root.scans.length !== 2 || root.scans[0] !== false || root.scans[1] !== true)
          throw new Error("queued full scan was not preserved")
        if (root.payloads[0] !== "initial" || root.payloads[1] !== "latest")
          throw new Error("queued refresh did not retain the newest command: " + JSON.stringify(root.payloads))
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
    if (!refreshController.request(initialCommand, false, false)) throw new Error("initial refresh did not start")
    if (refreshController.request(staleCommand, true, false)) throw new Error("concurrent refresh was not queued")
    if (refreshController.request(latestCommand, false, true)) throw new Error("replacement refresh was not coalesced")
    if (!refreshController.queuedRequest || !refreshController.queuedRequest.fullScan || !refreshController.queuedRequest.bypassCache)
      throw new Error("queued refresh flags were lost")
    if (refreshController.queuedRequest.baseCommand[2].indexOf("latest") < 0)
      throw new Error("queued refresh retained a superseded command")
  }
}
