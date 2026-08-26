import QtQuick
import Quickshell.Io

QtObject {
  id: controller
  required property string helper
  property bool busy: false
  property string activeMode: ""
  property bool undoAvailable: false
  readonly property bool running: busy

  signal succeeded(string mode, string payload)
  signal failed(string mode, int exitCode, string detail)

  function request(mode) {
    var selected = String(mode || "")
    if (busy || ["export", "import", "undo"].indexOf(selected) < 0) return false
    busy = true
    activeMode = selected
    process.mode = selected
    process.command = [helper, "settings-" + selected]
    process.running = true
    return true
  }
  function refreshUndoAvailability() {
    if (busy) return false
    busy = true; activeMode = "check"; process.mode = "check"
    process.command = [helper, "settings-can-undo"]; process.running = true
    return true
  }

  property Process process: Process {
    property string mode: ""
    stdout: StdioCollector { id: output; waitForEnd: true }
    stderr: StdioCollector { id: errorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var completedMode = process.mode
      var payload = String(output.text || "").trim()
      var detail = String(errorOutput.text || "").trim().slice(0, 512)
      controller.busy = false
      controller.activeMode = ""
      if (completedMode === "check") { controller.undoAvailable = exitCode === 0; return }
      if (exitCode === 0 && (completedMode === "import" || completedMode === "undo")) controller.undoAvailable = true
      if (exitCode === 0) controller.succeeded(completedMode, payload)
      else controller.failed(completedMode, exitCode, detail)
    }
  }
}
