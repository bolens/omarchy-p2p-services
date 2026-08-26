import QtQuick
import Quickshell.Io

QtObject {
  id: runner
  property bool busy: false
  readonly property bool running: busy
  property var activeEntry: null
  property string activeAction: ""
  property bool timedOut: false
  property int timeoutMilliseconds: 30000

  signal actionFinished(var entry, string action, int exitCode, string detail)

  function request(entry, action, command) {
    var selectedAction = String(action || "").trim()
    if (busy || !entry || !entry.id || selectedAction === "" || !Array.isArray(command) || command.length === 0
        || String(command[0] || "").trim() === "") return false
    busy = true
    timedOut = false
    activeEntry = entry
    activeAction = selectedAction
    process.command = command.slice()
    process.running = true
    watchdog.start()
    return true
  }

  property Process process: Process {
    stderr: StdioCollector { id: errorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      watchdog.stop()
      var entry = runner.activeEntry
      var action = runner.activeAction
      var detail = String(errorOutput.text || "").trim().slice(0, 512)
      runner.activeEntry = null
      runner.activeAction = ""
      runner.busy = false
      runner.actionFinished(entry, action, runner.timedOut ? -2 : exitCode, runner.timedOut ? "Operation timed out" : detail)
    }
  }
  property P2PProcessWatchdog watchdog: P2PProcessWatchdog {
    process: runner.process
    timeoutMilliseconds: runner.timeoutMilliseconds
    onTimedOut: runner.timedOut = true
  }
}
