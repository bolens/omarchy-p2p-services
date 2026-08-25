import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property bool collapsed: false
    property var values: ({groupHeaderStyle:"surfaced",showGroupIcons:true,showGroupCounts:true})
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function groupLabelFor(_entry) { return "FILE SYNC" }
    function showGroupHeading(index, _entry) { return index === 0 }
    function groupIcon(_entry) { return "S" }
    function groupCountText(_label) { return "1/2 active" }
    function isGroupCollapsed(_label) { return collapsed }
    function toggleGroup(_label) { collapsed = !collapsed }
  }

  P2PGroupHeader {
    id: header
    controller: mockController
    entry: ({id:"syncthing",category:"File sync",active:true})
    serviceIndex: 0
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
    var icon = descendant(header, "groupIcon")
    var count = descendant(header, "groupCountText")
    var indicator = descendant(header, "groupCollapseIndicator")
    if (!header.visible || header.groupName !== "FILE SYNC") throw new Error("group header visibility failed")
    if (!icon.visible || icon.text !== "S") throw new Error("group icon rendering failed")
    if (count.text !== "1/2 active" || indicator.text !== "▾") throw new Error("group summary rendering failed")
    header.activate()
    if (!mockController.collapsed || indicator.text !== "▸") throw new Error("group collapse event failed")
    mockController.values = Object.assign({}, mockController.values, {showGroupIcons:false,showGroupCounts:false})
    Qt.callLater(function() {
      if (icon.visible || descendant(header, "groupCountBadge").visible) throw new Error("group display toggles failed")
      console.log("P2P_QML_GROUP_HEADER_OK")
      Qt.quit()
    })
  })
}
