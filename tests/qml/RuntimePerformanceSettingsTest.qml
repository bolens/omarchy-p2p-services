import Quickshell
import QtQuick
import qs.Commons

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "performance"
    property int consecutiveRefreshFailures: 0
    property real configuredPanelWidth: Style.space(600)
    property var p2pService: null
    property var eventJournal: []
    property var patches: []
    property int reports: 0
    function setting(key, fallback) {
      var values = {refreshSeconds:5,backgroundRefreshSeconds:30,reconcileSeconds:90,eventRefresh:true,enableEventJournal:false}
      return values[key] === undefined ? fallback : values[key]
    }
    function persistKeepingOpen(patch) { patches = patches.concat([patch]) }
    function refreshHealthText() { return "Healthy · updated now" }
    function monitoringTelemetryText() { return "Watcher healthy" }
    function copySupportReport() { reports += 1 }
    function clearEventJournal() {}
  }

  P2PPerformanceSettings { id: page; width: 600; controller: mockController }

  function descendant(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    var children = item.children || []
    for (var index = 0; index < children.length; index++) {
      var match = descendant(children[index], name)
      if (match) return match
    }
    return null
  }
  function settingControl(item, key) {
    if (!item) return null
    if (item.settingKey === key) return item
    var children = item.children || []
    for (var index = 0; index < children.length; index++) {
      var match = settingControl(children[index], key)
      if (match) return match
    }
    return null
  }

  Component.onCompleted: Qt.callLater(function() {
    var cadence = descendant(page, "refreshCadenceGrid")
    var triggers = descendant(page, "refreshTriggerGrid")
    var traffic = descendant(page, "trafficSamplingGrid")
    var eventRefresh = settingControl(page, "eventRefresh")
    var refreshSeconds = settingControl(page, "refreshSeconds")
    var report = descendant(page, "copySupportReportButton")
    var afterSettings = descendant(page, "refreshAfterSettingsToggle")
    var afterActions = descendant(page, "refreshAfterActionsToggle")
    if (!cadence || !triggers || !traffic || !eventRefresh || !refreshSeconds || !report || !afterSettings || !afterActions) throw new Error("performance settings controls are not addressable")
    if (report.text !== "" || report.iconText !== "󰆏" || report.tooltipText !== "Copy privacy-filtered support report") throw new Error("support report action is not a descriptive icon control")
    if (!cadence.twoColumns || !triggers.twoColumns || !traffic.twoColumns) throw new Error("wide performance settings did not pair related controls")
    page.width = Style.space(420)
    mockController.configuredPanelWidth = Style.space(420)
    Qt.callLater(function() {
    if (cadence.twoColumns || cadence.columns !== 1)
      throw new Error("minimum-width refresh cadence did not collapse within the page")
    if (triggers.twoColumns) throw new Error("minimum-width refresh trigger grid retained two columns")
    if (traffic.twoColumns) throw new Error("minimum-width traffic grid retained two columns")
    if (page.sectionY("refresh") < 0 || page.sectionY("diagnostics") <= page.sectionY("refresh")) throw new Error("performance section navigation coordinates failed")
    if (afterSettings.tooltipText !== "Refresh after settings changes" || afterActions.tooltipText !== "Refresh after service actions") throw new Error("condensed refresh labels lost their full tooltips")
    eventRefresh.clicked()
    refreshSeconds.save()
    report.clicked()
    if (mockController.patches.length !== 2 || mockController.patches[0].eventRefresh !== false || mockController.patches[1].refreshSeconds !== 5) throw new Error("performance settings persistence failed")
    if (mockController.reports !== 1) throw new Error("support report action failed")
    console.log("P2P_QML_PERFORMANCE_SETTINGS_OK")
    Qt.quit()
    })
  })
}
