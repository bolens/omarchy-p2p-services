import Quickshell
import QtQuick

ShellRoot {
  id: root

  P2PSectionHeading {
    id: heading
    width: 400
    title: "Runtime section"
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
    var title = descendant(heading, "sectionHeadingTitle")
    var description = descendant(heading, "sectionHeadingDescription")
    if (!title || !description || title.text !== "RUNTIME SECTION") throw new Error("section heading content was not addressable")
    if (description.visible) throw new Error("empty section description retained layout space")
    heading.description = "Runtime details"
    if (!description.visible || description.text !== "Runtime details") throw new Error("section description did not appear with content")
    heading.description = ""
    if (description.visible) throw new Error("cleared section description retained layout space")
    console.log("P2P_QML_SECTION_HEADING_OK")
    Qt.quit()
  })
}
