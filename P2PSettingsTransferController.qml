import QtQuick
import Quickshell.Io

QtObject {
  id: controller
  required property string helper
  property bool busy: false
  property string activeMode: ""
  readonly property bool running: busy

  signal succeeded(string mode, string payload)
  signal failed(string mode, int exitCode)

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

  property Process process: Process {
    property string mode: ""
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(exitCode) {
      var completedMode = process.mode
      var payload = String(output.text || "").trim()
      controller.busy = false
      if (exitCode === 0) controller.succeeded(completedMode, payload)
      else controller.failed(completedMode, exitCode)
    }
  }
}
