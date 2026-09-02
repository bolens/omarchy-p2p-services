pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int failures: 0

  P2PRefreshController {
    id: refreshController
    onSucceeded: function(_payload, _fullScan) { throw new Error("failing refresh unexpectedly succeeded") }
    onFailed: function(exitCode, fullScan) {
      root.failures += 1
      if (exitCode === 0 || fullScan !== true) throw new Error("refresh failure payload failed")
      Qt.callLater(function() {
        if (refreshController.running || refreshController.queuedRequest) throw new Error("failed refresh did not return to idle")
        if (root.failures !== 1) throw new Error("refresh failure emitted more than once")
        console.log("P2P_QML_REFRESH_FAILURE_OK")
        Qt.quit()
      })
    }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("refresh failure test timed out") }
  }

  Component.onCompleted: {
    if (refreshController.request([], false, false)) throw new Error("empty refresh command was accepted")
    if (refreshController.request("/usr/bin/false", false, false)) throw new Error("non-array refresh command was accepted")
    if (refreshController.running || refreshController.queuedRequest) throw new Error("invalid refresh command changed controller state")
    if (!refreshController.request(["/usr/bin/false"], true, false)) throw new Error("failing refresh did not start")
  }
}
