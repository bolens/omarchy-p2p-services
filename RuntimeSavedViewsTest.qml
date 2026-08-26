import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var selected: null
  property var saved: [{name:"Transfers and synchronization",search:"sync",filter:"running",backend:"docker",sortMode:"traffic",sortDirection:"descending",groupMode:"category",groupDirection:"ascending",favoritesFirst:false}]

  QtObject {
    id: mockController
    function setting(key, fallback) { return key === "savedViews" ? root.saved : fallback }
    function applyView(view) { root.selected = view }
  }

  P2PSavedViews { id: views; controller: mockController }

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
    var button = descendant(views, "savedViewButton-0")
    if (!button || button.text !== "Transfers and sy" || button.tooltipText !== "Transfers and synchronization")
      throw new Error("saved view button presentation failed")
    button.clicked()
    if (!selected || selected.search !== "sync" || selected.filter !== "running" || selected.backend !== "docker") throw new Error("saved view filter event failed")
    if (selected.sortMode !== "traffic" || selected.sortDirection !== "descending") throw new Error("saved view sort event failed")
    if (selected.groupMode !== "category" || selected.groupDirection !== "ascending" || selected.favoritesFirst !== false) throw new Error("saved view grouping event failed")
    selected = null
    views.activate(4)
    if (selected !== null) throw new Error("invalid saved view activated")
    console.log("P2P_QML_SAVED_VIEWS_OK")
    Qt.quit()
  })
}
