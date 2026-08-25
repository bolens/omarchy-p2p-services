import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string editingServiceId: ""
    property bool showingWidgetSettings: false
    property bool collapsed: false
    property string selectedServiceId: ""
    property string pendingService: ""
    property string expandedServiceId: ""
    property string contextServiceId: ""
    property bool privacyFilter: true
    property string serviceLayout: "list"
    property var visibleServices: [
      {id:"syncthing",name:"Syncthing",category:"File sync",icon:"S",active:true,hasError:false,backend:"systemd",unit:"syncthing.service",unitScope:"user",configExists:false,hasWeb:false,processCount:1,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:60,connections:1,listeners:1},
      {id:"tailscale",name:"Tailscale",category:"Overlay network",icon:"T",active:false,hasError:false,backend:"systemd",unit:"tailscaled.service",unitScope:"system",configExists:false,hasWeb:false,processCount:0,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0},
      {id:"nebula",name:"Nebula",category:"Overlay network",icon:"N",active:false,hasError:false,backend:"systemd",unit:"nebula.service",unitScope:"system",configExists:false,hasWeb:false,processCount:0,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0}
    ]
    function setting(key, fallback) {
      var values = {serviceLayout:serviceLayout,serviceGroupMode:"category",groupHeaderStyle:"plain",showGroupIcons:true,showGroupCounts:true,cardDensity:"comfortable",showStatusRail:true,showCardSummary:true,showQuickActions:true,showTrafficStats:false,showBackendBadge:false,showFavoriteMarker:true}
      return values[key] === undefined ? fallback : values[key]
    }
    function groupLabelFor(entry) { return String(entry.category).toUpperCase() }
    function showGroupHeading(index, entry) { return index === 0 || groupLabelFor(visibleServices[index - 1]) !== groupLabelFor(entry) }
    function groupIcon(entry) { return entry.icon }
    function groupCountText(_label) { return "1/1 active" }
    function isGroupCollapsed(_label) { return collapsed }
    function toggleGroup(_label) { collapsed = !collapsed }
    function serviceColor(_entry) { return "#55aaff" }
    function iconFor(entry) { return entry.icon }
    function labelFor(entry) { return entry.name }
    function isFavorite(_id) { return false }
    function themeColor(_role, fallback) { return fallback }
    function trafficRate(_id, _field) { return false }
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

  P2PServiceList { id: serviceList; width: 600; controller: mockController }

  function cardIn(delegate) {
    if (!delegate) return null
    if (delegate.objectName === "serviceCard") return delegate
    var children = delegate.children || []
    for (var index = 0; index < children.length; index++) {
      var match = cardIn(children[index])
      if (match) return match
    }
    return null
  }

  function namedIn(delegate, name) {
    if (!delegate) return null
    if (delegate.objectName === name) return delegate
    var children = delegate.children || []
    for (var index = 0; index < children.length; index++) {
      var match = namedIn(children[index], name)
      if (match) return match
    }
    return null
  }

  Component.onCompleted: Qt.callLater(function() {
    var sync = serviceList.itemForId("syncthing")
    var tail = serviceList.itemForId("tailscale")
    var nebula = serviceList.itemForId("nebula")
    if (!sync || !tail || serviceList.itemAt(0) !== sync || serviceList.itemForId("missing") !== null)
      throw new Error("service list lookup failed")
    var syncCard = cardIn(sync)
    if (!syncCard || !syncCard.visible) throw new Error("expanded service group did not show its card")
    if (!namedIn(sync, "serviceGroupHeader").visible || !namedIn(tail, "serviceGroupHeader").visible || namedIn(nebula, "serviceGroupHeader").visible)
      throw new Error("category header repeated before every service")
    if (serviceList.gridView || serviceList.columns !== 1) throw new Error("list layout default failed")
    mockController.serviceLayout = "grid"
    Qt.callLater(function() {
      if (!serviceList.gridView || !serviceList.twoColumnGrid || serviceList.columns !== 2 || !syncCard.compact || !syncCard.grid || namedIn(sync, "serviceGroupHeader").visible) throw new Error("responsive grid layout failed")
      if (!namedIn(syncCard, "gridMetadataRow").visible || !namedIn(syncCard, "gridStatusPill")) throw new Error("grid card metadata did not reflow")
      serviceList.width = 400
      if (serviceList.twoColumnGrid || serviceList.columns !== 1) throw new Error("narrow grid did not collapse to one column")
      serviceList.width = 600
      mockController.serviceLayout = "list"
    mockController.collapsed = true
    Qt.callLater(function() {
      if (syncCard.visible) throw new Error("collapsed service group still showed its card")
      mockController.showingWidgetSettings = true
      Qt.callLater(function() {
        if (serviceList.itemAt(0) !== null || serviceList.itemForId("syncthing") !== null)
          throw new Error("service list remained populated behind settings")
        console.log("P2P_QML_SERVICE_LIST_OK")
        Qt.quit()
      })
    })
    })
  })
}
