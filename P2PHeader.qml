import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
  id: header
  required property var controller
  spacing: Style.spacing.md

  Rectangle {
    implicitWidth: Style.space(header.controller.setting("compactHeader", false) ? 38 : 48); implicitHeight: implicitWidth; radius: Style.cornerRadius
    color: Util.alpha(header.controller.errorCount > 0 ? Color.urgent : Color.accent, 0.12)
    Text { anchors.centerIn: parent; text: String(header.controller.setting("widgetIcon", "󰒍")); textFormat: Text.PlainText; color: header.controller.errorCount > 0 ? Color.urgent : Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.display }
  }
  ColumnLayout {
    Layout.preferredWidth: implicitWidth; spacing: Style.space(2)
    Text { text: "P2P Services"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.weight: Font.Bold }
    RowLayout {
      visible: header.controller.setting("compactHeader", false) !== true
      spacing: Style.spacing.xs
      StatusChip { label: header.controller.activeCount + " active"; tone: header.controller.themeColor(String(header.controller.setting("runningColorRole","accent")), Color.accent) }
      StatusChip { label: header.controller.stoppedCount + " stopped"; tone: header.controller.themeColor(String(header.controller.setting("stoppedColorRole","muted")), Color.muted) }
      StatusChip { visible: header.controller.errorCount > 0; label: header.controller.errorCount + " issues"; tone: header.controller.themeColor(String(header.controller.setting("errorColorRole","urgent")), Color.urgent) }
    }
    Text { visible: header.controller.setting("compactHeader", false) === true; text: header.controller.activeCount + " active · " + header.controller.stoppedCount + " stopped"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
  }
  Item { Layout.fillWidth: true }
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
    Text { id: chipText; anchors.centerIn: parent; text: parent.label.toUpperCase(); textFormat: Text.PlainText; color: parent.tone; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 0.7 }
  }
}
