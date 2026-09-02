pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property int activeCount: 7
    property int stoppedCount: 5
    property int errorCount: 2
    property string serviceFilter: "running"
    property string backendFilter: "docker"
    property string searchQuery: ""
    property var services: [{},{},{},{},{},{},{},{},{},{},{},{}]
    property var visibleServices: [{},{},{}]
    property int backendActivations: 0
    property var values: ({serviceLayout:"list",cardDensity:"comfortable"})
    property bool serviceGroupsVisible: true
    property bool allServiceGroupsCollapsed: false
    property var events: []
    function filterByBackend(_backend) { backendActivations += 1; backendFilter = "" }
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) { events = events.concat([patch]); values = Object.assign({}, values, patch) }
    function setAllServiceGroupsCollapsed(collapsed) { allServiceGroupsCollapsed = collapsed; events = events.concat([{allGroupsCollapsed:collapsed}]) }
  }

  ColumnLayout {
    id: filterHost
    width: 620
    P2PFilterBar { id: filterBar; Layout.fillWidth: true; controller: mockController }
  }
  ColumnLayout {
    id: narrowFilterHost
    x: 700
    width: 400
    P2PFilterBar { id: narrowFilterBar; Layout.fillWidth: true; controller: mockController }
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
    var backend = descendant(filterBar, "activeBackendFilterPill")
    var count = descendant(filterBar, "visibleServiceCountText")
    var primary = descendant(filterBar, "primaryFilterPill")
    var layout = descendant(filterBar, "serviceLayoutToggle")
    var density = descendant(filterBar, "cardDensityToggle")
    var groups = descendant(filterBar, "serviceGroupsCollapseToggle")
    var primaryFlow = descendant(filterBar, "primaryFilterFlow")
    var actions = descendant(filterBar, "filterActionRow")
    var toolbar = descendant(filterBar, "filterToolbar")
    var narrowPrimary = descendant(narrowFilterBar, "primaryFilterFlow")
    var narrowActions = descendant(narrowFilterBar, "filterActionRow")
    var narrowToolbar = descendant(narrowFilterBar, "filterToolbar")
    if (!backend || !count || !primary || !layout || !density || !groups || !primaryFlow || !actions || !toolbar || count.text !== "3 SHOWN") throw new Error("filter controls are not addressable")
    if (primaryFlow.height < primary.height || toolbar.height < primaryFlow.height || actions.y + actions.height > toolbar.height + 0.01) throw new Error("filter toolbar clips its controls")
    if (primaryFlow.y !== actions.y) throw new Error("wide filter toolbar did not use one row")
    if (Math.abs(actions.x + actions.width - toolbar.width) > 0.01 || primaryFlow.x !== 0) throw new Error("filter toolbar did not split left and right control groups")
    if (narrowToolbar.singleRow || narrowActions.y <= narrowPrimary.y) throw new Error("constrained filter toolbar did not wrap its action group")
    if (Math.abs(narrowActions.x + narrowActions.width - narrowToolbar.width) > 0.01) throw new Error("wrapped filter actions were not right-aligned")
    if (narrowActions.y + narrowActions.height > narrowToolbar.height + 0.01 || narrowPrimary.width > narrowToolbar.width + 0.01) throw new Error("wrapped filter toolbar clipped its controls")
    if (!groups.visible || groups.iconText !== "▴" || groups.tooltipText !== "Collapse all service groups") throw new Error("expanded groups did not expose collapse-all control")
    groups.clicked()
    if (!mockController.allServiceGroupsCollapsed || groups.iconText !== "▾" || groups.tooltipText !== "Expand all service groups") throw new Error("collapse-all control did not become expand-all")
    groups.clicked()
    if (mockController.allServiceGroupsCollapsed) throw new Error("expand-all control did not restore groups")
    mockController.serviceGroupsVisible = false
    if (groups.visible) throw new Error("group control remained visible without service groups")
    mockController.serviceGroupsVisible = true
    if (filterBar.primaryFilterCount !== 4 || primary.text !== "12" || primary.iconText !== "󰒍" || primary.tooltipText !== "All services (12)" || primary.width > filterBar.width / 3) throw new Error("primary filters were not rendered as compact icon-count controls")
    primary.clicked()
    if (mockController.serviceFilter !== "all") throw new Error("primary service filter action failed")
    layout.clicked()
    if (!layout.active || layout.tooltipText !== "Switch to single-column list") throw new Error("layout toggle did not reflect grid mode")
    density.clicked()
    if (density.text !== "" || density.iconText !== "☷" || density.tooltipText.indexOf("minimal") < 0) throw new Error("density toggle did not reflect compact mode")
    density.clicked()
    if (density.iconText !== "⋯" || density.tooltipText.indexOf("comfortable") < 0) throw new Error("density toggle did not reflect minimal mode")
    density.clicked()
    if (density.iconText !== "▤" || density.tooltipText.indexOf("compact") < 0) throw new Error("density toggle did not return to comfortable mode")
    if (mockController.events.length !== 6 || mockController.events[2].serviceLayout !== "grid") throw new Error("layout toggle event failed")
    if (mockController.values.cardDensity !== "comfortable") throw new Error("density toggle did not cycle all modes")
    backend.activate()
    if (mockController.backendActivations !== 1 || mockController.backendFilter !== "") throw new Error("backend filter pill did not remain actionable")
    if (backend.visible || count.parent.visible) throw new Error("cleared filters retained active filter indicators")
    mockController.searchQuery = "sync"
    if (!count.parent.visible || count.text !== "3 SHOWN") throw new Error("search filter did not reveal the result count")
    mockController.searchQuery = ""
    mockController.errorCount = 0
    Qt.callLater(function() {
      if (filterBar.primaryFilterCount !== 3) throw new Error("cleared issue count did not remove its compact filter")
    mockController.backendFilter = "docker"
    Qt.callLater(function() {
      console.log("P2P_QML_FILTER_BAR_OK")
      Qt.quit()
    })
    })
  })
}
