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

  Component.onCompleted: Qt.callLater(function() {
    watchdog.start()
    if (!watchdog.armed || !watchdog.timer.running) throw new Error("started watchdog was not armed")
    watchdog.stop()
    if (watchdog.armed || watchdog.timer.running) throw new Error("stopped watchdog retained its deadline")
    watchdog.start()
    watchdog.start()
    if (!watchdog.armed || !watchdog.timer.running || root.timeouts !== 0) throw new Error("watchdog restart did not reset cleanly")
    watchdog.timer.triggered()
    if (root.timeouts !== 1 || watchdog.armed) throw new Error("watchdog timeout was not single-shot")
    if (process.running) throw new Error("watchdog did not stop the timed-out process")
    watchdog.timer.triggered()
    if (root.timeouts !== 1) throw new Error("disarmed watchdog emitted a duplicate timeout")
    console.log("P2P_QML_PROCESS_WATCHDOG_OK")
    Qt.quit()
  })
}
