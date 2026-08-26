import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int stage: 0
  property int timeouts: 0

  QtObject { id: process; property bool running: true }
  P2PProcessWatchdog {
    id: watchdog
    process: process
    timeoutMilliseconds: 100
    onTimedOut: root.timeouts += 1
  }

  Timer {
    interval: 160
    running: true
    repeat: true
    onTriggered: {
      if (root.stage === 0) {
        if (root.timeouts !== 0 || watchdog.armed) throw new Error("stopped watchdog emitted a timeout")
        watchdog.start()
        if (!watchdog.armed) throw new Error("watchdog did not re-arm")
        root.stage = 1
      } else {
        if (root.timeouts !== 1 || watchdog.armed) throw new Error("watchdog timeout was not single-shot")
        if (process.running) throw new Error("watchdog did not stop the timed-out process")
        console.log("P2P_QML_PROCESS_WATCHDOG_OK")
        Qt.quit()
      }
    }
  }

  Component.onCompleted: {
    watchdog.start()
    watchdog.stop()
  }
}
