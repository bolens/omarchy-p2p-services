import QtQuick
import Quickshell.Io

QtObject {
  id: journal
  required property string helper
  property var events: []
  property bool busy: false
  property var queue: []
  signal failed()

  function hasHelper() { return String(helper || "").trim() !== "" }
  function operationPending(operation) {
    return (busy && process.command && process.command[1] === operation)
      || queue.some(function(command) { return command[1] === operation })
  }
  function load() {
    if (!hasHelper() || operationPending("events-list")) return false
    enqueue([helper, "events-list"])
    return true
  }
  function record(kind, count) {
    var eventKind = String(kind || "").trim()
    if (!hasHelper() || eventKind === "") return false
    enqueue([helper, "events-add", eventKind, String(Math.max(1, Number(count) || 1))])
    return true
  }
  function clear() {
    if (!hasHelper() || operationPending("events-clear")) return false
    enqueue([helper, "events-clear"])
    return true
  }
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
