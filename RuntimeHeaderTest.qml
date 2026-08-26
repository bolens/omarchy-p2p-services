import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property int activeCount: 2
    property int stoppedCount: 3
    property int errorCount: 1
    property string editingServiceId: "syncthing"
    property bool showingWidgetSettings: false
    property var values: ({compactHeader:false,widgetIcon:"H"})
    property var refreshCalls: []
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function themeColor(_role, fallback) { return fallback }
    function refresh(forceCatalog, fullContainers, bypassCache) {
      refreshCalls = refreshCalls.concat([{forceCatalog:forceCatalog,fullContainers:fullContainers,bypassCache:bypassCache}])
    }
  }

  P2PHeader { id: header; controller: mockController }

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

  Component.onCompleted: Qt.callLater(function() {
    var settings = descendant(header, "headerSettingsButton")
    var refresh = descendant(header, "headerRefreshButton")
    var statusChips = descendant(header, "headerStatusChips")
    var activeStatus = descendant(header, "headerActiveStatusText")
    var stoppedStatus = descendant(header, "headerStoppedStatusText")
    var issueStatus = descendant(header, "headerIssueStatus")
    var compactSummary = descendant(header, "headerCompactSummary")
    var iconSurface = descendant(header, "headerIconSurface")
    var icon = descendant(header, "headerIcon")
    if (!settings || !refresh || !statusChips || !activeStatus || !stoppedStatus || !issueStatus || !compactSummary || !iconSurface || !icon) throw new Error("header controls are not addressable")
    if (!statusChips.visible || compactSummary.visible || activeStatus.text !== "2 ACTIVE" || stoppedStatus.text !== "3 STOPPED" || !issueStatus.visible || icon.text !== "H")
      throw new Error("expanded header status presentation failed")
    mockController.values = Object.assign({}, mockController.values, {compactHeader:true})
    Qt.callLater(function() {
    if (statusChips.visible || !compactSummary.visible || compactSummary.text !== "2 active · 3 stopped · 1 issues" || iconSurface.implicitWidth >= 48)
      throw new Error("compact header did not preserve status in a smaller footprint")
    mockController.errorCount = 0
    if (issueStatus.visible || compactSummary.text !== "2 active · 3 stopped") throw new Error("cleared issue status remained visible")
    settings.clicked()
    if (!mockController.showingWidgetSettings || mockController.editingServiceId !== "") throw new Error("header settings action failed")
    refresh.clicked()
    if (mockController.refreshCalls.length !== 1) throw new Error("header refresh event count failed")
    var call = mockController.refreshCalls[0]
    if (!call.forceCatalog || !call.fullContainers || !call.bypassCache) throw new Error("header refresh flags failed")
    console.log("P2P_QML_HEADER_OK")
    Qt.quit()
    })
  })
}
