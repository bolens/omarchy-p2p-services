import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Window
import qs.Commons as Commons

ShellRoot {
  id: root
  property int actions: 0
  property int frameStage: 0
  property real wideHeight: 0

  PanelWindow {
    id: messageWindow
    implicitWidth: 520
    implicitHeight: 260
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: true
    Connections {
      target: messageWindow.contentItem.Window.window
      function onFrameSwapped() { root.verifyFrame() }
    }
    P2PMessageSurface {
      id: surface
      width: 520
      message: "Service refresh failed"
      actionText: "Diagnostics"
      tone: Commons.Color.urgent
      onActionRequested: root.actions += 1
    }
  }

  function descendant(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    var children = item.children || []
    for (let index = 0; index < children.length; index++) {
      const match = descendant(children[index], name)
      if (match) return match
    }
    return null
  }

  function verifyFrame() {
    if (root.frameStage === 3) return
    var action = descendant(surface, "messageSurfaceAction")
    if (root.frameStage === 0) {
      if (!action || !action.visible || !action.bordered || !action.selected) throw new Error("diagnostics action is not visibly themed")
      if (action.accent.toString() !== surface.tone.toString()) throw new Error("diagnostics action did not inherit the message tone")
      action.clicked()
      if (root.actions !== 1) throw new Error("diagnostics action event failed")
      root.wideHeight = surface.implicitHeight
      root.frameStage = 1
      surface.actionText = ""
      surface.width = 180
      surface.message = "Service refresh failed because the helper returned an unexpectedly long diagnostic message"
    } else if (root.frameStage === 1) {
      if (action.visible) throw new Error("empty message action retained button space")
      if (surface.implicitHeight <= root.wideHeight) throw new Error("narrow diagnostic message did not grow to preserve wrapped text: " + root.wideHeight + " -> " + surface.implicitHeight)
      root.frameStage = 2
      surface.actionText = "Retry"
    } else if (root.frameStage === 2) {
      if (!action.visible || action.text !== "Retry") throw new Error("message action did not return after its label changed")
      root.frameStage = 3
      messageWindow.visible = false
      if (messageWindow.visible) throw new Error("owned message fixture window did not close")
      console.log("P2P_QML_MESSAGE_SURFACE_OK")
      Qt.quit()
    }
  }
}
