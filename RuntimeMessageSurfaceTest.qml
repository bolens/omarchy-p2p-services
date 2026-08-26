import Quickshell
import QtQuick
import qs.Commons

ShellRoot {
  id: root
  property int actions: 0

  P2PMessageSurface {
    id: surface
    width: 520
    message: "Service refresh failed"
    actionText: "Diagnostics"
    tone: Color.urgent
    onActionRequested: root.actions += 1
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
    var action = descendant(surface, "messageSurfaceAction")
    if (!action || !action.visible || !action.bordered || !action.selected) throw new Error("diagnostics action is not visibly themed")
    if (action.accent.toString() !== surface.tone.toString()) throw new Error("diagnostics action did not inherit the message tone")
    action.clicked()
    if (root.actions !== 1) throw new Error("diagnostics action event failed")
    console.log("P2P_QML_MESSAGE_SURFACE_OK")
    Qt.quit()
  })
}
