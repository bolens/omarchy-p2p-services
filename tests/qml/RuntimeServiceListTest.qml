import Quickshell
import QtQuick

ShellRoot {
  id: root

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
    property string cardDensity: "comfortable"
    property var visibleServices: [
      {id:"syncthing",name:"Syncthing",category:"File sync",icon:"S",active:true,hasError:false,backend:"systemd",unit:"syncthing.service",unitScope:"user",configExists:false,hasWeb:false,processCount:1,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:60,connections:1,listeners:1},
      {id:"tailscale",name:"Tailscale",category:"Overlay network",icon:"T",active:false,hasError:false,backend:"systemd",unit:"tailscaled.service",unitScope:"system",configExists:false,hasWeb:false,processCount:0,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0},
      {id:"nebula",name:"Nebula",category:"Overlay network",icon:"N",active:false,hasError:false,backend:"systemd",unit:"nebula.service",unitScope:"system",configExists:false,hasWeb:false,processCount:0,containerCount:0,pids:[],endpoints:[],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0}
    ]
    function setting(key, fallback) {
      var values = {serviceLayout:serviceLayout,serviceGroupMode:"category",groupHeaderStyle:"plain",showGroupIcons:true,showGroupCounts:true,cardDensity:cardDensity,showStatusRail:true,showCardSummary:true,showQuickActions:true,showTrafficStats:false,showBackendBadge:false,showFavoriteMarker:true}
      return values[key] === undefined ? fallback : values[key]
    }
    function groupLabelFor(entry) { return String(entry.category).toUpperCase() }
    function showGroupHeading(index, groupName) { return index === 0 || groupLabelFor(visibleServices[index - 1]) !== groupName }
    function groupIcon(entry) { return entry.icon }
    function groupCountText(_label) { return "1/1 active" }
    function isGroupCollapsed(label) { return collapsedGroups[label] === true }
    function toggleGroup(label) { var next = Object.assign({}, collapsedGroups); next[label] = next[label] !== true; collapsedGroups = next }
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
    if (serviceList.contentWidthHint <= 0 || serviceList.contentWidthHint >= serviceList.width)
      throw new Error("list did not expose an intrinsic content width")
    mockController.serviceLayout = "grid"
    Qt.callLater(function() {
      sync = serviceList.itemForId("syncthing")
      syncCard = cardIn(sync)
      if (!serviceList.gridView || !serviceList.twoColumnGrid || serviceList.columns !== 2 || !syncCard || syncCard.compact || !syncCard.grid) throw new Error("responsive comfortable grid layout failed")
      var gridHeader = namedIn(serviceList, "gridGroupHeader")
      if (serviceList.gridSectionCount !== 2 || !gridHeader || !gridHeader.visible)
        throw new Error("grid did not split grouped services into headed sections")
      if (serviceList.contentWidthHint <= syncCard.contentWidthHint || serviceList.contentWidthHint >= serviceList.width)
        throw new Error("grid did not expose a content-driven two-column width")
      if (!namedIn(syncCard, "comfortableMetadata").visible || namedIn(syncCard, "gridStatusPill").visible)
        throw new Error("comfortable grid did not preserve glanceable metadata")
      mockController.collapsedGroups = ({"OVERLAY NETWORK":true})
      Qt.callLater(function() {
      if (serviceList.gridSectionCount !== 2 || serviceList.itemForId("tailscale") !== null || serviceList.itemForId("nebula") !== null || !serviceList.itemForId("syncthing"))
        throw new Error("collapsed grid group did not retain its section while removing service cards")
      if (!namedIn(serviceList, "gridGroupHeader").visible)
        throw new Error("collapsed grid group removed its actionable heading")
      mockController.collapsedGroups = ({})
      Qt.callLater(function() {
      if (!serviceList.itemForId("tailscale") || !serviceList.itemForId("nebula"))
        throw new Error("expanded grid group did not restore service cards")
      serviceList.width = 320
      if (serviceList.twoColumnGrid || serviceList.columns !== 1) throw new Error("narrow grid did not collapse to one column")
      serviceList.width = 600
      mockController.cardDensity = "minimal"
      Qt.callLater(function() {
      serviceList.width = 400
      if (!serviceList.twoColumnGrid || serviceList.columns !== 2) throw new Error("viable minimal grid collapsed to a list")
      mockController.serviceLayout = "list"
    mockController.collapsedGroups = ({"OVERLAY NETWORK":true})
    Qt.callLater(function() {
      var collapsedTail = serviceList.itemForId("tailscale")
      var collapsedNebula = serviceList.itemForId("nebula")
      var visibleSync = serviceList.itemForId("syncthing")
      if (!collapsedTail || !collapsedTail.visible || !collapsedNebula || collapsedNebula.visible || !visibleSync || !cardIn(visibleSync).visible)
        throw new Error("collapsed list group retained hidden service row spacing")
      var collapsedHeader = namedIn(collapsedTail, "serviceGroupHeader")
      if (!collapsedHeader || !collapsedHeader.visible || collapsedTail.implicitHeight !== collapsedHeader.implicitHeight)
        throw new Error("collapsed list group did not reduce to its header footprint: delegate=" + collapsedTail.implicitHeight + " header=" + (collapsedHeader ? collapsedHeader.implicitHeight : -1))
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
    })
    })
  })
}
