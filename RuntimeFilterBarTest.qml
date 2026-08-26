import Quickshell
import QtQuick

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
    property var events: []
    function filterByBackend(_backend) { backendActivations += 1; backendFilter = "" }
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) { events = events.concat([patch]); values = Object.assign({}, values, patch) }
  }

  P2PFilterBar { id: filterBar; width: 620; controller: mockController }

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
    var primaryGrid = descendant(filterBar, "primaryFilterGrid")
    if (!backend || !count || !primary || !layout || !density || !primaryGrid || count.text !== "3 SHOWN") throw new Error("filter controls are not addressable")
    if (filterBar.primaryFilterCount !== 4 || !filterBar.primaryFiltersWide || primary.width <= primary.minimumPillWidth) throw new Error("wide primary filters did not fill their row evenly")
    primary.clicked()
    if (mockController.serviceFilter !== "all") throw new Error("primary service filter action failed")
    layout.clicked()
    if (!layout.active || layout.tooltipText !== "Switch to single-column list") throw new Error("layout toggle did not reflect grid mode")
    density.clicked()
    if (density.text !== "Compact" || density.tooltipText.indexOf("minimal") < 0) throw new Error("density toggle did not reflect compact mode")
    density.clicked()
    if (density.text !== "Minimal" || density.tooltipText.indexOf("comfortable") < 0) throw new Error("density toggle did not reflect minimal mode")
    density.clicked()
    if (density.text !== "Comfortable" || density.tooltipText.indexOf("compact") < 0) throw new Error("density toggle did not return to comfortable mode")
    if (mockController.events.length !== 4 || mockController.events[0].serviceLayout !== "grid") throw new Error("layout toggle event failed")
    if (mockController.values.cardDensity !== "comfortable") throw new Error("density toggle did not cycle all modes")
    backend.activate()
    if (mockController.backendActivations !== 1 || mockController.backendFilter !== "") throw new Error("backend filter pill did not remain actionable")
    mockController.backendFilter = "docker"
    filterBar.width = 150
    Qt.callLater(function() {
      if (filterBar.primaryFiltersWide || primaryGrid.columns !== 2) throw new Error("narrow primary filters did not switch to two columns")
      console.log("P2P_QML_FILTER_BAR_OK")
      Qt.quit()
    })
  })
}
