import QtQuick
import Quickshell.Io
import "Model.js" as Model
import "PathUtils.js" as PathUtils

Item {
  id: root
  property var shell: null
  property var manifest: null
  property var settings: ({})
  property var services: []
  property var diagnostics: []
  property string refreshError: ""
  property int refreshSerial: 0
  property bool lastFullScan: true
  property int lastDurationMs: 0
  property double lastRefreshAt: 0
  property double watcherLastHeartbeatAt: 0
  property string watcherHealth: "starting"
  property string watcherCode: "waiting"
  property bool watcherPollingOnly: false
  property int watcherRetryMilliseconds: 1000
  property int durableSettingsRevision: -1
  property string helper: PathUtils.localFilePath(Qt.resolvedUrl("p2p-control"))

  function configure(next) {
    settings = next && typeof next === "object" && !Array.isArray(next) ? next : {}
    durableSettingsRevision = Math.max(durableSettingsRevision, Number(settings._p2pRevision) || 0)
    if (settings.eventRefresh === false) {
      watcherProc.running = false
      eventRefreshDelay.stop()
      watcherRetry.stop()
      watcherHealth = "disabled"
      watcherCode = "disabled"
    } else if (!watcherPollingOnly && !watcherProc.running && !watcherRetry.running) watcherRetry.start()
  }

  function requestRefresh(fullContainers, bypassCache) {
    refreshController.request([helper, "status", settings.privacyFilter === false ? "unsafe" : "private",
      String(settings.consoleHost || "").trim(), settings.showTrafficStats === false ? "no-stats" : "stats"],
      fullContainers, bypassCache)
  }

  function monitoringTelemetry() {
    var now = Date.now()
    return {
      watcherHealth: watcherHealth,
      watcherCode: watcherCode,
      watcherRunning: watcherProc.running,
      watcherHeartbeatAgeSeconds: watcherLastHeartbeatAt > 0 ? Math.max(0, Math.round((now - watcherLastHeartbeatAt) / 1000)) : -1,
      watcherRetryMilliseconds: watcherRetryMilliseconds,
      lastRefreshAgeSeconds: lastRefreshAt > 0 ? Math.max(0, Math.round((now - lastRefreshAt) / 1000)) : -1,
      lastDurationMs: lastDurationMs,
      diagnostics: diagnostics.length
    }
  }

  P2PRefreshController {
    id: refreshController
    onSucceeded: function(text, fullScan) {
      try {
        var payload = JSON.parse(text || "{}")
        if (!payload || !Array.isArray(payload.services)) throw new Error("missing service list")
        root.services = payload.services
        root.diagnostics = Array.isArray(payload.diagnostics) ? payload.diagnostics : []
        root.lastDurationMs = Number(payload.durationMs) || 0
        root.lastFullScan = fullScan
        root.lastRefreshAt = Date.now()
        root.refreshError = ""
        root.refreshSerial++
      } catch (error) { root.refreshError = "Unable to parse shared P2P status" }
    }
    onFailed: root.refreshError = "Shared P2P status scan failed"
  }

  Process {
    id: settingsWatcherProc
    command: [root.helper, "settings-watch"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var event = JSON.parse(line)
          if (event.type === "settings-changed" && Number(event.revision) > root.durableSettingsRevision)
            root.durableSettingsRevision = Number(event.revision)
        } catch (error) {}
      }
    }
    onExited: settingsWatcherRetry.restart()
  }
  Timer { id: settingsWatcherRetry; interval: 1000; onTriggered: settingsWatcherProc.running = true }
  Process {
    id: watcherProc
    command: [root.helper, "watch"]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var state = Model.parseWatcherEvent(line, Date.now())
        if (!state.accepted) return
        root.watcherLastHeartbeatAt = state.heartbeatAt
        root.watcherHealth = state.health
        root.watcherCode = state.code
        if (state.code === "polling-only") root.watcherPollingOnly = true
        root.watcherRetryMilliseconds = state.retryMilliseconds
        if (state.changed) eventRefreshDelay.restart()
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 3) {
        root.watcherPollingOnly = true
        root.watcherHealth = "polling"
        root.watcherCode = "polling-only"
        watcherRetry.stop()
        return
      }
      var state = Model.watcherExitState(root.settings.eventRefresh !== false, root.watcherRetryMilliseconds)
      if (!state.retry) return
      root.watcherHealth = state.health; root.watcherCode = state.code
      root.watcherPollingOnly = false
      watcherRetry.interval = state.delay
      root.watcherRetryMilliseconds = state.nextRetryMilliseconds
      watcherRetry.restart()
    }
  }
  Timer { id: eventRefreshDelay; interval: 750; onTriggered: if (root.settings.eventRefresh !== false) root.requestRefresh(true, false) }
  Timer { id: watcherRetry; interval: root.watcherRetryMilliseconds; onTriggered: if (root.settings.eventRefresh !== false) watcherProc.running = true }
  Timer {
    interval: 5000; repeat: true; running: root.settings.eventRefresh !== false
    onTriggered: {
      var state = Model.watcherHeartbeatState(root.watcherLastHeartbeatAt, Date.now(), 45000)
      if (!state.stale) return
      root.watcherHealth = state.health; root.watcherCode = state.code
      if (!root.watcherPollingOnly && !watcherProc.running && !watcherRetry.running) watcherRetry.restart()
    }
  }
  Component.onCompleted: watcherRetry.start()
}
