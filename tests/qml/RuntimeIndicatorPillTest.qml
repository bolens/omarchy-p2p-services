pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int activations: 0

  P2PIndicatorPill {
    id: pill
    indicator: ({icon:"C",value:3,tooltip:"3 connected peers"})
    tone: "#88aaff"
    onTriggered: root.activations += 1
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
    var count = descendant(pill, "indicatorPillCount")
    if (!count || count.text !== "3" || !count.visible) throw new Error("indicator value was not presented")
    if (!pill.interactive || pill.Accessible.name !== "3 connected peers") throw new Error("interactive indicator accessibility failed")
    pill.activate()
    if (root.activations !== 1) throw new Error("interactive indicator activation failed")
    pill.indicator = ({icon:"U",value:0,tooltip:"Uptime unavailable",enabled:false})
    if (pill.interactive || pill.opacity >= 1) throw new Error("disabled indicator was not visibly disabled")
    pill.activate()
    if (root.activations !== 1) throw new Error("disabled indicator still activated")
    if (count.text !== "0" || !count.visible) throw new Error("zero indicator value was hidden")
    console.log("P2P_QML_INDICATOR_PILL_OK")
    Qt.quit()
  })
}
