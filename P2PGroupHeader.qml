import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: header
  required property var controller
  required property var entry
  required property int serviceIndex
  property bool layoutVisible: true
  property string groupName: controller.groupLabelFor(entry)

  objectName: "serviceGroupHeader"
  visible: layoutVisible && controller.showGroupHeading(serviceIndex, groupName)
  Layout.fillWidth: true
  implicitHeight: groupRow.implicitHeight + (controller.setting("groupHeaderStyle", "surfaced") === "dense" ? Style.spacing.xs : Style.spacing.sm) * 2
  radius: Style.cornerRadius
  color: Util.alpha(Color.muted, controller.setting("groupHeaderStyle", "surfaced") === "dense" ? 0 : 0.045)
  border.width: controller.setting("groupHeaderStyle", "surfaced") === "dense" ? 0 : 1
  border.color: Util.alpha(Color.muted, 0.13)

  function activate() { controller.toggleGroup(groupName) }

  RowLayout {
    id: groupRow
    anchors.fill: parent
    anchors.margins: Style.spacing.sm
    Text { objectName: "groupCollapseIndicator"; text: controller.isGroupCollapsed(header.groupName) ? "▸" : "▾"; textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body }
    Text { objectName: "groupIcon"; visible: controller.setting("showGroupIcons", true) === true; text: controller.groupIcon(header.entry); textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body }
    Text { objectName: "groupLabel"; Layout.fillWidth: true; text: header.groupName; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 1.1 }
    Rectangle {
      objectName: "groupCountBadge"
      visible: controller.setting("showGroupCounts", true) === true
      implicitWidth: countText.implicitWidth + Style.spacing.sm * 2
      implicitHeight: countText.implicitHeight + Style.space(4)
      radius: implicitHeight / 2
      color: Util.alpha(Color.accent, 0.10)
      Text { id: countText; objectName: "groupCountText"; anchors.centerIn: parent; text: controller.groupCountText(header.groupName); textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold }
    }
  }
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: header.activate() }
}
