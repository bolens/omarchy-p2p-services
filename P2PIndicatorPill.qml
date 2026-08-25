import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
  id: pill
  property var indicator: ({})
  required property color tone
  property int horizontalPadding: Style.spacing.sm
  signal activated

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: String(indicator.tooltip || "Service information")
  implicitWidth: indicatorRow.implicitWidth + horizontalPadding * 2
  implicitHeight: indicatorRow.implicitHeight + Style.space(4)
  radius: implicitHeight / 2
  color: Util.alpha(tone, hovered || activeFocus ? 0.20 : 0.11)
  border.width: activeFocus ? 2 : 1
  border.color: Util.alpha(tone, activeFocus ? 0.8 : 0.25)
  readonly property bool hovered: pointer.containsMouse

  Row {
    id: indicatorRow
    anchors.centerIn: parent
    spacing: Style.space(3)
    Text { text: pill.indicator.icon; textFormat: Text.PlainText; color: pill.tone; font.family: Style.font.family; font.pixelSize: Style.font.caption }
    Text { objectName: "indicatorPillCount"; visible: text !== ""; text: String(pill.indicator.value || ""); textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.mono || Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.activated()
  }
  Keys.onReturnPressed: activated()
  Keys.onEnterPressed: activated()
  Keys.onSpacePressed: activated()
  ToolTip.visible: hovered
  ToolTip.text: String(indicator.tooltip || "")
}
