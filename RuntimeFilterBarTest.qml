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
    function filterByBackend(_backend) { backendActivations += 1; backendFilter = "" }
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
    var wideHeight = filterBar.childrenRect.height
    var backend = descendant(filterBar, "activeBackendFilterPill")
    var count = descendant(filterBar, "visibleServiceCountText")
    if (!backend || !count || count.text !== "3 SHOWN") throw new Error("filter controls are not addressable")
    backend.activate()
    if (mockController.backendActivations !== 1 || mockController.backendFilter !== "") throw new Error("backend filter pill did not remain actionable")
    mockController.backendFilter = "docker"
    filterBar.width = 250
    Qt.callLater(function() {
      if (filterBar.childrenRect.height <= wideHeight) throw new Error("narrow filter controls did not wrap: wide=" + wideHeight + " narrow=" + filterBar.childrenRect.height + " implicit=" + filterBar.implicitHeight + " children=" + filterBar.children.length)
      console.log("P2P_QML_FILTER_BAR_OK")
      Qt.quit()
    })
  })
}
