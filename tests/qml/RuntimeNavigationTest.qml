pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "Model.js" as Model

ShellRoot {
  id: root

  property Item harness: Item {
    width: 360
    height: 240
    property int selectedIndex: -1
    property alias scrollPosition: viewport.contentY

    function move(delta) {
      selectedIndex = Model.nextSelectionIndex(cards.count, selectedIndex, delta)
      var item = cards.itemAt(selectedIndex)
      var position = item.mapToItem(viewport.contentItem, 0, 0)
      viewport.contentY = Model.ensureVisibleContentY(
        viewport.contentY, viewport.height, position.y, item.height, viewport.contentHeight)
    }

    Flickable {
      id: viewport
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.height
      clip: true

      Column {
        id: content
        width: viewport.width
        height: childrenRect.height
        Rectangle { width: parent.width; height: 120 }
        Repeater {
          id: cards
          model: 5
          delegate: Rectangle {
            required property int index
            width: content.width
            height: 80
            objectName: "service-" + index
          }
        }
      }
    }
  }

  Component.onCompleted: Qt.callLater(function() {
    content.forceLayout()
    viewport.contentHeight = content.childrenRect.height
    harness.move(1)
    if (harness.selectedIndex !== 0 || Math.abs(harness.scrollPosition) > 0.01) throw new Error("initial Down navigation failed")
    harness.move(1)
    harness.move(1)
    if (harness.selectedIndex !== 2 || Math.abs(harness.scrollPosition - 120) > 0.01)
      throw new Error("mapped downward scroll failed: index=" + harness.selectedIndex + " contentY=" + harness.scrollPosition)
    harness.selectedIndex = -1
    harness.scrollPosition = 0
    harness.move(-1)
    if (harness.selectedIndex !== 4 || Math.abs(harness.scrollPosition - 280) > 0.01)
      throw new Error("initial Up navigation failed: index=" + harness.selectedIndex + " contentY=" + harness.scrollPosition)
    console.log("P2P_QML_NAVIGATION_OK")
    Qt.quit()
  })
}
