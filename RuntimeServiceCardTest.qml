import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string selectedServiceId: ""
    property string pendingService: ""
    property string pendingAction: ""
    property string expandedServiceId: ""
    property string contextServiceId: ""
    property bool privacyFilter: true
    property string density: "comfortable"
    property string layout: "list"
    property var events: []
    function setting(key, fallback) {
      var values = {serviceLayout:layout,cardDensity:density,showStatusRail:true,showCardSummary:true,showQuickActions:true,showTrafficStats:false,showBackendBadge:true,showFavoriteMarker:true}
      return values[key] === undefined ? fallback : values[key]
    }
    function serviceColor(_entry) { return "#55aaff" }
    function iconFor(_entry) { return "S" }
    function labelFor(_entry) { return "Home Sync" }
    function isFavorite(_id) { return false }
    function themeColor(_role, fallback) { return fallback }
    function trafficRate(_id, _field) { return false }
    function hasConsole(_entry) { return false }
    function serviceActionLabel(id) { return pendingService === id ? (pendingAction === "start" ? "STARTING" : "WORKING") : "" }
    function act(entry, action) { events = events.concat([{kind:"action",id:entry.id,action:action}]) }
    function toggleServiceDetails(id) { events = events.concat([{kind:"details",id:id}]); expandedServiceId = expandedServiceId === id ? "" : id }
    function editService(_id) {}
    function toggleServiceContext(_id) {}
    function toggleFavorite(_id) {}
    function openLogs(_entry) {}
    function copyDiagnostics(_entry) {}
    function openConsole(entry) { events = events.concat([{kind:"console",id:entry.id}]) }
    function filterByBackend(backend) { events = events.concat([{kind:"backend",backend:backend}]) }
  }

  P2PServiceCard {
    id: card
    width: 600
    controller: mockController
    entry: ({id:"syncthing",name:"Syncthing",icon:"S",active:false,hasError:false,backend:"systemd",unit:"syncthing.service",unitScope:"user",config:"/home/alice/.config/syncthing/config.xml",configExists:true,hasWeb:false,processCount:0,containerCount:0,pids:[4242],endpoints:["10.0.0.2:22000 → 10.0.0.3:22000"],restartCount:0,lastTransition:"",failureReason:"",uptime:0,connections:0,listeners:0})
  }

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
    var status = descendant(card, "serviceStatusText")
    var primary = descendant(card, "servicePrimaryActionButton")
    var details = descendant(card, "serviceDetailsButton")
    var quickActions = descendant(card, "serviceQuickActions")
    var actionLoading = descendant(card, "serviceActionLoadingIndicator")
    var expandedDetails = descendant(card, "serviceExpandedDetails")
    var expandedDetailsContent = descendant(card, "serviceExpandedDetailsContent")
    var detailsSeparator = descendant(card, "serviceDetailsSeparator")
    var runtimeDetails = descendant(card, "serviceRuntimeDetailsText")
    if (!status || !primary || !details || !quickActions || !actionLoading || !expandedDetails || !expandedDetailsContent || !detailsSeparator || !runtimeDetails) throw new Error("service card controls are not addressable")
    if (status.text !== "STOPPED" || primary.text !== "Start" || !quickActions.visible) throw new Error("stopped service presentation failed")
    primary.clicked()
    details.clicked()
    if (mockController.events.length !== 2 || mockController.events[0].action !== "start" || mockController.events[1].kind !== "details")
      throw new Error("service card action dispatch failed")
    if (mockController.expandedServiceId !== "syncthing" || !details.active || details.text !== "Hide details")
      throw new Error("service details state failed")
    if (!expandedDetails.visible || !detailsSeparator.visible || expandedDetails.horizontalInset <= 0
        || expandedDetailsContent.x < expandedDetails.horizontalInset
        || expandedDetailsContent.width > expandedDetails.width - expandedDetails.horizontalInset * 2)
      throw new Error("expanded service details did not retain an inset from the separator")
    if (/4242|alice|10\.0\.0\./.test(runtimeDetails.text)) throw new Error("private expanded details leaked process, path, or endpoint data")
    mockController.privacyFilter = false
    if (!/4242/.test(runtimeDetails.text) || !/alice/.test(runtimeDetails.text) || !/10\.0\.0\.2/.test(runtimeDetails.text))
      throw new Error("explicitly unfiltered expanded details omitted runtime data")
    mockController.privacyFilter = true
    mockController.pendingService = "syncthing"
    mockController.pendingAction = "start"
    Qt.callLater(function() {
      if (status.visible || !actionLoading.visible || actionLoading.label !== "STARTING" || primary.enabled) throw new Error("pending service presentation failed")
      card.entry = Object.assign({}, card.entry, {controllable:false})
      mockController.density = "compact"
      Qt.callLater(function() {
        if (primary.visible) throw new Error("observation-only service exposed mutation control")
        var disabledConfigPill = null
        function findDisabledConfigPill(item) {
          if (!item) return null
          if (item.objectName === "compactIndicatorPill" && item.indicator && item.indicator.action === "config") return item
          var children = item.children || []
          for (var index = 0; index < children.length; index++) { var match = findDisabledConfigPill(children[index]); if (match) return match }
          return null
        }
        disabledConfigPill = findDisabledConfigPill(card)
        if (!disabledConfigPill || disabledConfigPill.enabled || disabledConfigPill.Accessible.name.indexOf("Observation only") < 0)
          throw new Error("observation-only config pill did not explain its disabled state")
        var beforeDisabledActivation = mockController.events.length
        disabledConfigPill.activate()
        if (mockController.events.length !== beforeDisabledActivation) throw new Error("disabled config pill dispatched an action")
        card.entry = Object.assign({}, card.entry, {controllable:true,active:true,connections:2,listeners:1,processCount:1,hasWeb:true,configExists:true})
        mockController.pendingService = ""
        mockController.density = "compact"
        Qt.callLater(function() {
          var pill = descendant(card, "compactIndicatorPill"), count = descendant(card, "indicatorPillCount")
          if (!pill || !count || count.text !== "2" || primary.text !== "" || primary.tooltipText !== "Stop service") throw new Error("compact icon card presentation failed")
          var beforePillEvents = mockController.events.length
          pill.activate()
          if (mockController.events.length !== beforePillEvents + 1 || mockController.events[beforePillEvents].kind !== "details") throw new Error("compact indicator pill did not dispatch details")
          var webPill = null
          function findWebPill(item) {
            if (!item) return null
            if (item.objectName === "compactIndicatorPill" && item.indicator && item.indicator.action === "console") return item
            var children = item.children || []
            for (var index = 0; index < children.length; index++) { var match = findWebPill(children[index]); if (match) return match }
            return null
          }
          webPill = findWebPill(card)
          if (!webPill) throw new Error("web console indicator pill missing")
          webPill.activate()
          if (mockController.events[mockController.events.length - 1].kind !== "console") throw new Error("web console indicator pill did not dispatch")
          var backendPill = descendant(card, "backendIndicatorPill")
          if (!backendPill) throw new Error("backend indicator pill missing")
          backendPill.activate()
          if (mockController.events[mockController.events.length - 1].kind !== "backend") throw new Error("backend indicator pill did not filter")
          mockController.layout = "grid"
          Qt.callLater(function() {
            var statusPill = descendant(card, "gridStatusPill")
            if (!statusPill) throw new Error("grid status pill missing")
            var beforeStatusEvents = mockController.events.length
            statusPill.activate()
            if (mockController.events.length !== beforeStatusEvents + 1 || mockController.events[beforeStatusEvents].kind !== "details") throw new Error("grid status pill did not dispatch details")
            mockController.layout = "list"
          mockController.density = "minimal"
          Qt.callLater(function() {
            if (status.visible || quickActions.visible) throw new Error("minimal indicator card retained verbose surfaces")
            console.log("P2P_QML_SERVICE_CARD_OK")
            Qt.quit()
          })
          })
        })
      })
    })
  })
}
