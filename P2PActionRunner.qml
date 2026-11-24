import QtQuick
import Quickshell.Io
import "Model.js" as Model

QtObject {
  id: runner
  property bool busy: false
  readonly property bool running: busy
  property var activeEntry: null
  property string activeAction: ""
  property bool timedOut: false
  property int timeoutMilliseconds: 30000
  property int authorizationTimeoutMilliseconds: 240000
  property int activeTimeoutMilliseconds: timeoutMilliseconds
  property string phase: ""

  function handleProgress(line) {
    if (!busy) return false
    try {
      const event = JSON.parse(line)
      if (["authorization","applying","verifying"].indexOf(event.phase) < 0) return false
      phase = event.phase
      return true
    } catch (error) { return false }
  }

  signal actionFinished(var entry, string action, int exitCode, string detail)

  function request(entry, action, command) {
    var selectedAction = String(action || "").trim()
    if (busy || !entry || !entry.id || selectedAction === "" || !Model.isList(command) || command.length === 0
        || String(command[0] || "").trim() === "") return false
    busy = true
    timedOut = false
    activeEntry = entry
    activeAction = selectedAction
    activeTimeoutMilliseconds = entry.authorizationRequired === true ? Math.max(timeoutMilliseconds, authorizationTimeoutMilliseconds) : timeoutMilliseconds
    phase = entry.authorizationRequired === true ? "authorization" : "applying"
    process.command = command.slice()
    process.running = true
    watchdog.start()
    return true
  }

  property Process process: Process {
    stdout: SplitParser { onRead: function(line) { runner.handleProgress(line) } }
    stderr: StdioCollector { id: errorOutput; waitForEnd: true }
    onExited: function(exitCode) {
      runner.watchdog.stop()
      var entry = runner.activeEntry
      var action = runner.activeAction
      var detail = String(errorOutput.text || "").trim().slice(0, 512)
      runner.activeEntry = null
      runner.activeAction = ""
      runner.busy = false
      runner.phase = ""
      runner.actionFinished(entry, action, runner.timedOut ? -2 : exitCode, runner.timedOut ? "Operation timed out" : detail)
    }
  }
  property P2PProcessWatchdog watchdog: P2PProcessWatchdog {
    process: runner.process
    timeoutMilliseconds: runner.activeTimeoutMilliseconds
    onTimedOut: runner.timedOut = true
  }
}
