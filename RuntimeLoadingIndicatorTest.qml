import Quickshell
import QtQuick

ShellRoot {
  id: root
  P2PLoadingIndicator { id: indicator; running: true; label: "LOADING TEST DATA"; style: "dots"; speed: 60 }

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

  Timer {
    interval: 100
    running: true
    onTriggered: {
      var frame = descendant(indicator, "loadingFrame"), label = descendant(indicator, "loadingLabel")
      if (!frame || !label || label.text !== "LOADING TEST DATA" || frame.text === ".  ") throw new Error("animated loading presentation failed")
      indicator.style = "glyph"
      indicator.glyph = "#"
      if (frame.text !== "#") throw new Error("custom loading glyph failed")
      indicator.glyph = "   "
      if (frame.text !== ">") throw new Error("blank loading glyph fallback failed")
      indicator.running = false
      if (indicator.visible) throw new Error("stopped loading indicator remained visible")
      console.log("P2P_QML_LOADING_INDICATOR_OK")
      Qt.quit()
    }
  }
}
