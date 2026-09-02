import QtQuick
import Quickshell.Io

QtObject {
  id: journal
  required property string helper
  property var events: []
  property bool busy: false
  property var queue: []
  readonly property int maximumQueuedCommands: 100
  readonly property int maximumQueuedCommandBytes: 262144
  signal failed()

  function hasHelper() { return String(helper || "").trim() !== "" }
  function operationPending(operation) {
    return (busy && process.command && process.command[1] === operation)
      || queue.some(function(command) { return command[1] === operation })
  }
  function load() {
    if (!hasHelper() || operationPending("events-list")) return false
    return enqueue([helper, "events-list"])
  }
  function record(kind, count) {
    var eventKind = String(kind || "").trim()
    if (!hasHelper() || eventKind === "") return false
    return enqueue([helper, "events-add", eventKind, String(Math.max(1, Number(count) || 1))])
  }
  function clear() {
    if (!hasHelper() || operationPending("events-clear")) return false
    return enqueue([helper, "events-clear"])
  }
  function enqueue(command) {
    if (queuedCommandBytes([command]) > maximumQueuedCommandBytes) return false
    var next = command[1] === "events-clear" ? [] : queue.slice()
    next = next.concat([command])
    while (next.length > maximumQueuedCommands || queuedCommandBytes(next) > maximumQueuedCommandBytes)
      next.shift()
    if (!next.length) return false
    queue = next
    startNext()
    return true
  }
  function queuedCommandBytes(commands) {
    try { return unescape(encodeURIComponent(JSON.stringify(commands))).length }
    catch (error) { return Number.POSITIVE_INFINITY }
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
