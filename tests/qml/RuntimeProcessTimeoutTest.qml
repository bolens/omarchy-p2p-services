pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root

  P2PActionRunner {
    id: runner
    timeoutMilliseconds: 100
    onActionFinished: function(entry, action, exitCode, detail) {
      if (entry.id !== "slow" || action !== "start") throw new Error("timeout lost operation identity")
      if (exitCode !== -2 || detail !== "Operation timed out") throw new Error("timeout result was not normalized")
      if (runner.running) throw new Error("runner remained busy after timeout")
      console.log("P2P_QML_PROCESS_TIMEOUT_OK")
      Qt.quit()
    }
  }

  Component.onCompleted: {
    if (!runner.request({id:"slow"}, "start", ["/usr/bin/sh", "-c", "sleep 2"]))
      throw new Error("slow operation was rejected")
  }
}
