import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Rectangle {
  id: surface
  required property string message
  property string icon: "󰋼"
  property color tone: Color.muted
  property string actionText: ""
  signal actionRequested()
  Layout.fillWidth: true
  implicitHeight: Math.max(messageRow.implicitHeight, messageText.contentHeight) + Style.spacing.md * 2
  radius: Style.cornerRadius
  color: Util.alpha(tone, 0.055)
  border.width: 1
  border.color: Util.alpha(tone, 0.18)
  RowLayout {
    id: messageRow
    anchors.fill: parent
    anchors.margins: Style.spacing.md
    spacing: Style.spacing.sm
    Text { text: surface.icon; textFormat: Text.PlainText; color: surface.tone; font.family: Style.font.family; font.pixelSize: Style.font.icon }
    Text { id: messageText; Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 0; text: surface.message; textFormat: Text.PlainText; color: Color.popups.text; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.body }
    Button {
      objectName: "messageSurfaceAction"
      visible: surface.actionText !== ""
      text: surface.actionText
      foreground: Color.popups.text
      accent: surface.tone
      bordered: true
      selected: true
      onClicked: surface.actionRequested()
    }
  }
}
