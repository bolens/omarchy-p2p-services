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

    service.lastDurationMs = 42
    service.diagnostics = [{code:"sample"}]
    service.lastRefreshAt = Date.now() - 2500
    service.watcherLastHeartbeatAt = Date.now() - 1500
    var telemetry = service.monitoringTelemetry()
    if (telemetry.lastDurationMs !== 42 || telemetry.diagnostics !== 1) throw new Error("service monitoring counters failed")
    if (telemetry.lastRefreshAgeSeconds < 2 || telemetry.lastRefreshAgeSeconds > 3) throw new Error("service refresh age failed")
    if (telemetry.watcherHeartbeatAgeSeconds < 1 || telemetry.watcherHeartbeatAgeSeconds > 2) throw new Error("watcher heartbeat age failed")
    console.log("P2P_QML_SERVICE_LIFECYCLE_OK")
    Qt.quit()
  }
}
