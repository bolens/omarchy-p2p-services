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
    property var refreshCalls: []
    function setting(_key, fallback) { return fallback }
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
    if (!settings || !refresh) throw new Error("header actions are not addressable")
    settings.clicked()
    if (!mockController.showingWidgetSettings || mockController.editingServiceId !== "") throw new Error("header settings action failed")
    refresh.clicked()
    if (mockController.refreshCalls.length !== 1) throw new Error("header refresh event count failed")
    var call = mockController.refreshCalls[0]
    if (!call.forceCatalog || !call.fullContainers || !call.bypassCache) throw new Error("header refresh flags failed")
    console.log("P2P_QML_HEADER_OK")
    Qt.quit()
  })
}
