import QtQuick
import Quickshell.Io

QtObject {
  id: journal
  required property string helper
  property var events: []
  property bool busy: false
  property var queue: []
  signal failed()

  function load() { enqueue([helper, "events-list"]) }
  function record(kind, count) { enqueue([helper, "events-add", String(kind), String(Math.max(1, Number(count) || 1))]) }
  function clear() { enqueue([helper, "events-clear"]) }
  function enqueue(command) {
    queue = queue.concat([command])
    startNext()
  }
  function startNext() {
    if (busy || !queue.length) return
    var next = queue.slice(); process.command = next.shift(); queue = next
    busy = true; process.running = true
  }

  property Process process: Process {
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(exitCode) {
      journal.busy = false
      if (exitCode !== 0) journal.failed()
      else if (process.command[1] !== "events-clear") {
        try { var parsed = JSON.parse(String(output.text || "[]")); journal.events = Array.isArray(parsed) ? parsed : [] }
        catch (error) { journal.failed() }
      } else journal.events = []
      Qt.callLater(journal.startNext)
    }
  }
}
