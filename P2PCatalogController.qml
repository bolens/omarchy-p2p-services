import QtQuick
import Quickshell.Io
import "Model.js" as Model

QtObject {
  id: controller
  required property string helper
  property bool busy: false
  property bool pending: false
  property bool timedOut: false
  property int timeoutMilliseconds: 30000
  readonly property bool running: busy

  signal updated(var entries)
  signal failed(int exitCode)

  function request() {
    if (busy) { pending = true; return false }
    busy = true
    timedOut = false
    process.command = [helper, "catalog"]
    process.running = true
    watchdog.start()
    return true
  }

  property Process process: Process {
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(exitCode) {
      watchdog.stop()
      var effectiveExitCode = controller.timedOut ? -2 : exitCode
      var entries = effectiveExitCode === 0 ? Model.parseCatalog(String(output.text || "").trim()) : null
      var rerun = controller.pending
      controller.pending = false
      controller.busy = false
      if (effectiveExitCode !== 0 || !entries) controller.failed(effectiveExitCode === 0 ? -1 : effectiveExitCode)
      else controller.updated(entries)
      if (rerun) Qt.callLater(function() { if (!controller.busy) controller.request() })
    }
  }
  property P2PProcessWatchdog watchdog: P2PProcessWatchdog {
    process: controller.process
    timeoutMilliseconds: controller.timeoutMilliseconds
    onTimedOut: controller.timedOut = true
  }
}
