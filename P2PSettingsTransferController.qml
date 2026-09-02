import QtQuick
import Quickshell.Io

QtObject {
  id: controller
  required property string helper
  property bool busy: false
  property string activeMode: ""
  property bool undoAvailable: false
  property bool timedOut: false
  property int timeoutMilliseconds: 30000
  readonly property bool running: busy

  signal succeeded(string mode, string payload)
  signal failed(string mode, int exitCode, string detail)

  function hasHelper() { return String(helper || "").trim() !== "" }
  function request(mode) {
    var selected = String(mode || "")
    if (busy || !hasHelper() || ["export", "import", "undo"].indexOf(selected) < 0) return false
    busy = true
    timedOut = false
    activeMode = selected
    process.mode = selected
    process.command = [helper, "settings-" + selected]
    process.running = true
    watchdog.start()
    return true
  }
  function refreshUndoAvailability() {
    if (busy || !hasHelper()) return false
    busy = true; timedOut = false; activeMode = "check"; process.mode = "check"
    process.command = [helper, "settings-can-undo"]; process.running = true; watchdog.start()
    return true
  }

  property Process process: Process {
    property string mode: ""
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { id: errorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      watchdog.stop()
      var completedMode = process.mode
      var effectiveExitCode = controller.timedOut ? -2 : exitCode
      var payload = String(output.text || "").trim()
      var detail = String(errorOutput.text || "").trim().slice(0, 512)
      if (completedMode === "check") controller.undoAvailable = effectiveExitCode === 0
      if (effectiveExitCode === 0 && (completedMode === "import" || completedMode === "undo")) controller.undoAvailable = true
      controller.activeMode = ""
      controller.busy = false
      if (completedMode === "check") return
      if (effectiveExitCode === 0) controller.succeeded(completedMode, payload)
      else controller.failed(completedMode, effectiveExitCode, controller.timedOut ? "Operation timed out" : detail)
    }
  }
  property P2PProcessWatchdog watchdog: P2PProcessWatchdog {
    process: controller.process
    timeoutMilliseconds: controller.timeoutMilliseconds
    onTimedOut: controller.timedOut = true
  }
}
