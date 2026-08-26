import Quickshell
import QtQuick

ShellRoot {
  id: root

  Service { id: service }

  Component.onCompleted: {
    service.configure(["not", "settings"])
    if (Array.isArray(service.settings) || Object.keys(service.settings).length !== 0)
      throw new Error("service accepted a non-object settings payload")

    service.configure({eventRefresh:false,privacyFilter:true})
    if (service.settings.privacyFilter !== true || service.watcherHealth !== "disabled" || service.watcherCode !== "disabled")
      throw new Error("event refresh disablement failed")
    service.configure({eventRefresh:false,_p2pRevision:7})
    service.configure({eventRefresh:false,_p2pRevision:3})
    if (service.durableSettingsRevision !== 7) throw new Error("durable settings revision regressed")
    var settingsEventAt = Date.now() - 1000
    if (!service.handleSettingsWatcherLine('{"type":"settings-changed","revision":9}', settingsEventAt)
        || service.durableSettingsRevision !== 9 || service.settingsWatcherHealth !== "healthy"
        || service.settingsWatcherLastEventAt !== settingsEventAt || service.settingsWatcherRetryMilliseconds !== 1000)
      throw new Error("settings watcher event health failed")
    if (service.handleSettingsWatcherLine("not-json", 6000)) throw new Error("settings watcher accepted malformed event")
    service.handleSettingsWatcherExit(7)
    if (service.settingsWatcherHealth !== "degraded" || service.settingsWatcherCode !== "retrying"
        || service.settingsWatcherLastExitCode !== 7 || service.settingsWatcherRetryMilliseconds !== 2000)
      throw new Error("settings watcher retry health failed")

    service.lastDurationMs = 42
    service.diagnostics = [{code:"sample"}]
    service.lastRefreshAt = Date.now() - 2500
    service.watcherLastHeartbeatAt = Date.now() - 1500
    var telemetry = service.monitoringTelemetry()
    if (telemetry.lastDurationMs !== 42 || telemetry.diagnostics !== 1) throw new Error("service monitoring counters failed")
    if (telemetry.lastRefreshAgeSeconds < 2 || telemetry.lastRefreshAgeSeconds > 3) throw new Error("service refresh age failed")
    if (telemetry.watcherHeartbeatAgeSeconds < 1 || telemetry.watcherHeartbeatAgeSeconds > 2) throw new Error("watcher heartbeat age failed")
    if (telemetry.settingsWatcherHealth !== "degraded" || telemetry.settingsWatcherLastExitCode !== 7
        || telemetry.settingsWatcherLastEventAgeSeconds !== 1) throw new Error("settings watcher telemetry failed")
    console.log("P2P_QML_SERVICE_LIFECYCLE_OK")
    Qt.quit()
  }
}
