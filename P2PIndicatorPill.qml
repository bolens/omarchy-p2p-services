import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
  id: pill
  property var indicator: ({})
  required property color tone
  property int horizontalPadding: Style.spacing.sm
  signal triggered
  function activate() { if (enabled) triggered() }

  activeFocusOnTab: true
  enabled: indicator.enabled !== false
  Accessible.role: Accessible.Button
  Accessible.name: String(indicator.tooltip || "Service information")
  Accessible.onPressAction: activate()
  implicitWidth: indicatorRow.implicitWidth + horizontalPadding * 2
  implicitHeight: indicatorRow.implicitHeight + Style.space(4)
  radius: implicitHeight / 2
  color: Util.alpha(tone, hovered || activeFocus ? 0.20 : 0.11)
  border.width: activeFocus ? 2 : 1
  border.color: Util.alpha(tone, activeFocus ? 0.8 : 0.25)
  opacity: enabled ? 1 : 0.45
  readonly property bool hovered: hoverDetector.hovered

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
    enabled: pill.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: pill.activate()
  }
  HoverHandler { id: hoverDetector }
  Keys.onReturnPressed: activate()
  Keys.onEnterPressed: activate()
  Keys.onSpacePressed: activate()
  ToolTip.visible: hoverDetector.hovered
  ToolTip.text: String(indicator.tooltip || "")
}
