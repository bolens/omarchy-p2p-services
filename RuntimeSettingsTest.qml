import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "services"
    property var values: ({
      serviceSortMode:"custom", serviceSortDirection:"automatic",
      serviceGroupMode:"none", serviceGroupDirection:"automatic",
      groupCountMode:"active-total", showGroupCounts:true,
      showGroupIcons:true, savedViews:[], showTrafficStats:true
    })
    property var patches: []
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) {
      patches = patches.concat([patch])
      values = Object.assign({}, values, patch)
    }
    function saveCurrentView(_name) {}
    function applyView(_view) {}
    function removeSavedView(_name) {}
  }

  P2PServicesSettings {
    id: settingsPage
    width: 600
    controller: mockController
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

  function select(name, value) {
    var dropdown = descendant(settingsPage, name)
    if (!dropdown) throw new Error("missing organization dropdown: " + name)
    dropdown.changed(value)
  }

  Component.onCompleted: Qt.callLater(function() {
    for (var gridName of ["serviceSortGrid", "servicePriorityGrid", "serviceGroupingGrid", "groupDisplayGrid"]) {
      var grid = descendant(settingsPage, gridName)
      if (!grid || !grid.twoColumns) throw new Error("wide services settings grid missing: " + gridName)
    }
    select("serviceSortModeDropdown", "name")
    select("serviceSortDirectionDropdown", "descending")
    select("serviceGroupModeDropdown", "scope")
    select("serviceGroupDirectionDropdown", "ascending")
    select("groupCountModeDropdown", "active")
    var expected = [
      ["serviceSortMode","name"], ["serviceSortDirection","descending"],
      ["serviceGroupMode","scope"], ["serviceGroupDirection","ascending"],
      ["groupCountMode","active"]
    ]
    if (mockController.patches.length !== expected.length) throw new Error("organization event count mismatch")
    for (var index = 0; index < expected.length; index++) {
      var key = expected[index][0]
      if (mockController.patches[index][key] !== expected[index][1]) throw new Error("organization event payload mismatch: " + key)
    }
    console.log("P2P_QML_SETTINGS_OK")
    Qt.quit()
  })
}
