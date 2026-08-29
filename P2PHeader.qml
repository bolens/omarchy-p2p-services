import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
  id: header
  required property var controller
  readonly property bool narrow: width < Style.space(420)
  spacing: Style.spacing.md

  Rectangle {
    objectName: "headerIconSurface"
    visible: !header.narrow
    implicitWidth: Style.space(header.controller.setting("compactHeader", false) ? 38 : 48); implicitHeight: implicitWidth; radius: Style.cornerRadius
    color: Util.alpha(header.controller.errorCount > 0 ? Color.urgent : Color.accent, 0.12)
    Text { objectName: "headerIcon"; anchors.centerIn: parent; text: String(header.controller.setting("widgetIcon", "󰒍")); textFormat: Text.PlainText; color: header.controller.errorCount > 0 ? Color.urgent : Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
  }
  ColumnLayout {
    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: Style.space(2)
    Text { Layout.fillWidth: true; text: "P2P Services"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.weight: Font.Bold; elide: Text.ElideRight }
    RowLayout {
      objectName: "headerStatusChips"
      visible: header.controller.setting("compactHeader", false) !== true && !header.narrow
      spacing: Style.spacing.xs
      StatusChip { objectName: "headerActiveStatus"; label: header.controller.activeCount + " active"; tone: header.controller.themeColor(String(header.controller.setting("runningColorRole","accent")), Color.accent) }
      StatusChip { objectName: "headerStoppedStatus"; label: header.controller.stoppedCount + " stopped"; tone: header.controller.themeColor(String(header.controller.setting("stoppedColorRole","muted")), Color.muted) }
      StatusChip { objectName: "headerIssueStatus"; visible: header.controller.errorCount > 0; label: header.controller.errorCount + " issues"; tone: header.controller.themeColor(String(header.controller.setting("errorColorRole","urgent")), Color.urgent) }
    }
    Text { objectName: "headerCompactSummary"; visible: header.controller.setting("compactHeader", false) === true || header.narrow; text: header.controller.activeCount + " active · " + header.controller.stoppedCount + " stopped" + (header.controller.errorCount > 0 ? " · " + header.controller.errorCount + " issues" : ""); textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.fillWidth: true }
  }
  RowLayout {
    id: headerActions
    Layout.alignment: Qt.AlignRight
    spacing: Style.spacing.xs
    Button { objectName: "headerSettingsButton"; iconText: "󰒓"; tooltipText: "Settings"; horizontalPadding: Style.spacing.controlGap; onClicked: { header.controller.editingServiceId = ""; header.controller.showingWidgetSettings = true } }
    Button { objectName: "headerRefreshButton"; iconText: "󰑐"; tooltipText: "Refresh"; horizontalPadding: Style.spacing.controlGap; onClicked: header.controller.refresh(true, true, true) }
  }

  component StatusChip: Rectangle {
    required property string label
    required property color tone
    implicitWidth: chipText.implicitWidth + Style.spacing.sm * 2
    implicitHeight: chipText.implicitHeight + Style.space(4)
    radius: implicitHeight / 2
    color: Util.alpha(tone, 0.10)
    border.width: 1
    border.color: Util.alpha(tone, 0.24)
    Text { id: chipText; objectName: parent.objectName + "Text"; anchors.centerIn: parent; text: parent.label.toUpperCase(); textFormat: Text.PlainText; color: parent.tone; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 0.7 }
  }
}
