pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root
  Item {
    id: host
    property bool presentationActive: true
    P2PLoadingIndicator { id: indicator; running: true; animationEnabled: host.presentationActive; label: "LOADING TEST DATA"; style: "dots"; speed: 60 }
  }

  function descendant(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    var objects = item.data || item.children || []
    for (var index = 0; index < objects.length; index++) {
      var match = descendant(objects[index], name)
      if (match) return match
    }
    return null
  }

  Component.onCompleted: Qt.callLater(function() {
      var frame = descendant(indicator, "loadingFrame"), label = descendant(indicator, "loadingLabel")
      var animationTimer = descendant(indicator, "loadingAnimationTimer")
      if (!frame || !label || !animationTimer || !indicator.animationRunning || label.text !== "LOADING TEST DATA") throw new Error("animated loading presentation failed")
      var initialFrame = frame.text
      animationTimer.triggered()
      if (frame.text === initialFrame) throw new Error("animation trigger did not advance its frame")
      if (indicator.animationInterval !== 60) throw new Error("initial animation cadence was not exposed")
      indicator.speed = 1
      if (indicator.animationInterval !== 60) throw new Error("animation cadence minimum was bypassed")
      indicator.speed = 90
      if (indicator.animationInterval !== 90 || !indicator.animationRunning) throw new Error("live animation cadence change did not apply cleanly")
      indicator.style = "glyph"
      indicator.glyph = "#"
      if (frame.text !== "#") throw new Error("custom loading glyph failed")
      indicator.glyph = "   "
      if (frame.text !== ">") throw new Error("blank loading glyph fallback failed")
      indicator.style = "dots"
      host.presentationActive = false
      host.visible = false
      Qt.callLater(function() {
        if (indicator.animationRunning) throw new Error("loading animation continued inside a hidden parent")
        host.visible = true
        host.presentationActive = true
        Qt.callLater(function() {
          if (!indicator.animationRunning) throw new Error("loading animation did not resume with its parent: enabled=" + indicator.animationEnabled + " running=" + indicator.running + " frames=" + indicator.frames.length)
          indicator.running = false
          if (indicator.visible || indicator.animationRunning) throw new Error("stopped loading indicator retained presentation work")
          console.log("P2P_QML_LOADING_INDICATOR_OK")
          Qt.quit()
        })
      })
  })
}
