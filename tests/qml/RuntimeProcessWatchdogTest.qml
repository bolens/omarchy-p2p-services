import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int timeouts: 0

  QtObject { id: process; property bool running: true }
  P2PProcessWatchdog {
    id: watchdog
    process: process
    timeoutMilliseconds: 100
    onTimedOut: root.timeouts += 1
  }

  Timer {
    interval: 60
    running: true
    onTriggered: {
      if (root.timeouts !== 0 || !watchdog.armed) throw new Error("watchdog timed out before its initial deadline")
      watchdog.start()
    }
  }

  Timer {
    interval: 130
    running: true
    onTriggered: {
      if (root.timeouts !== 0 || !watchdog.armed || !process.running) throw new Error("watchdog restart retained the original deadline")
    }
  }

  Timer {
    interval: 190
    running: true
    onTriggered: {
      if (root.timeouts !== 1 || watchdog.armed) throw new Error("watchdog timeout was not single-shot")
      if (process.running) throw new Error("watchdog did not stop the timed-out process")
      console.log("P2P_QML_PROCESS_WATCHDOG_OK")
      Qt.quit()
    }
  }

  Component.onCompleted: {
    watchdog.start()
    watchdog.stop()
    if (watchdog.armed) throw new Error("stopped watchdog remained armed")
    watchdog.start()
  }
}
