pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
  id: controller
  property var queuedRequest: null
  property bool busy: false
  property bool timedOut: false
  property int timeoutMilliseconds: 30000
  readonly property bool running: busy
  readonly property bool activeFullScan: process.fullScan

  signal succeeded(string payload, bool fullScan)
  signal failed(int exitCode, bool fullScan)

  function request(baseCommand, fullScan, bypassCache) {
    if (!Array.isArray(baseCommand) || baseCommand.length === 0 || String(baseCommand[0] || "").trim() === "") return false
    var next = {baseCommand:baseCommand.slice(),fullScan:fullScan === true,bypassCache:bypassCache === true}
    if (busy) {
      if (queuedRequest) {
        next.fullScan = next.fullScan || queuedRequest.fullScan === true
        next.bypassCache = next.bypassCache || queuedRequest.bypassCache === true
      }
      queuedRequest = next
      return false
    }
    start(next)
    return true
  }

  function start(request) {
    busy = true
    timedOut = false
    process.fullScan = request.fullScan === true
    process.command = request.baseCommand.concat([
      process.fullScan ? "all-containers" : "running-containers",
      request.bypassCache === true ? "bypass-cache" : "use-cache"
    ])
    process.running = true
    watchdog.start()
  }

  function drain() {
    if (!queuedRequest) {
      busy = false
      return
    }
    var next = queuedRequest
    queuedRequest = null
    busy = true
    Qt.callLater(function() { controller.start(next) })
  }

  property Process process: Process {
    property bool fullScan: false
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(exitCode) {
      controller.watchdog.stop()
      var fullScan = controller.process.fullScan
      if (exitCode === 0 && !controller.timedOut) controller.succeeded(String(output.text || "").trim(), fullScan)
      else controller.failed(controller.timedOut ? -2 : exitCode, fullScan)
      controller.drain()
    }
  }
  property P2PProcessWatchdog watchdog: P2PProcessWatchdog {
    process: controller.process
    timeoutMilliseconds: controller.timeoutMilliseconds
    onTimedOut: controller.timedOut = true
  }
}
