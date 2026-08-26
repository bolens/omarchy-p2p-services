import Quickshell
import QtQuick

ShellRoot {
  id: root

  function service(id, name, category) {
    return {id:id,name:name,category:category,icon:name.charAt(0),active:false,hasError:false,backend:"systemd",unit:id + ".service",unitScope:"user",configExists:false,hasWeb:false,processCount:0,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0}
  }

  QtObject {
    id: mockController
    property string editingServiceId: ""
    property bool showingWidgetSettings: false
    property var collapsedGroups: ({})
    property string selectedServiceId: ""
    property string pendingService: ""
    property string expandedServiceId: ""
    property string contextServiceId: ""
    property bool privacyFilter: true
    property string serviceLayout: "list"
    property var visibleServices: [root.service("alpha", "Alpha", "Shared"), root.service("beta", "Beta", "Shared")]
    function setting(key, fallback) {
      var values = {serviceLayout:serviceLayout,serviceGroupMode:"category",groupHeaderStyle:"plain",showGroupIcons:true,showGroupCounts:true,cardDensity:"minimal",showStatusRail:true,showCardSummary:true,showQuickActions:true,showTrafficStats:false,showBackendBadge:false,showFavoriteMarker:true}
      return values[key] === undefined ? fallback : values[key]
    }
    function groupLabelFor(entry) { return String(entry.category).toUpperCase() }
    function showGroupHeading(index, groupName) { return index === 0 || groupLabelFor(visibleServices[index - 1]) !== groupName }
    function groupIcon(entry) { return entry.icon }
    function groupCountText(_label) { return "0/1 active" }
    function isGroupCollapsed(label) { return collapsedGroups[label] === true }
    function serviceColor(_entry) { return "#55aaff" }
    function iconFor(entry) { return entry.icon }
    function labelFor(entry) { return entry.name }
    function isFavorite(_id) { return false }
    function themeColor(_role, fallback) { return fallback }
    function trafficRate(_id, _field) { return false }
    function serviceActionLabel(_id) { return "" }
    function hasConsole(_entry) { return false }
    function act(_entry, _action) {}
    function toggleServiceDetails(_id) {}
    function editService(_id) {}
    function toggleServiceContext(_id) {}
    function toggleFavorite(_id) {}
    function openLogs(_entry) {}
    function copyDiagnostics(_entry) {}
    function openConsole(_entry) {}
  }

  P2PServiceList { id: serviceList; width: 520; controller: mockController }

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
    var alpha = serviceList.itemForId("alpha")
    var beta = serviceList.itemForId("beta")
    if (!alpha || !beta || serviceList.itemAt(0) !== alpha || descendant(beta, "serviceGroupHeader").visible)
      throw new Error("initial list delegates did not share one category heading")
    mockController.visibleServices = [root.service("beta", "Beta", "Second"), root.service("alpha", "Alpha", "First")]
    Qt.callLater(function() {
      alpha = serviceList.itemForId("alpha")
      beta = serviceList.itemForId("beta")
      if (!alpha || !beta || serviceList.itemAt(0) !== beta || !descendant(alpha, "serviceGroupHeader").visible || !descendant(beta, "serviceGroupHeader").visible)
        throw new Error("list delegates did not follow a reordered replacement model")
      mockController.serviceLayout = "grid"
      Qt.callLater(function() {
        if (serviceList.gridSectionCount !== 2 || serviceList.itemAt(0) !== serviceList.itemForId("beta"))
          throw new Error("grid sections did not follow the replacement model")
        mockController.visibleServices = [root.service("alpha", "Alpha", "First")]
        Qt.callLater(function() {
          if (serviceList.gridSectionCount !== 1 || !serviceList.itemForId("alpha") || serviceList.itemForId("beta"))
            throw new Error("grid did not remove filtered service delegates")
          mockController.visibleServices = []
          Qt.callLater(function() {
            if (serviceList.gridSectionCount !== 0 || serviceList.itemAt(0) !== null || serviceList.contentWidthHint !== 0)
              throw new Error("empty replacement model retained grid delegates or width")
            console.log("P2P_QML_SERVICE_LIST_MUTATION_OK")
            Qt.quit()
          })
        })
      })
    })
  })
}
