import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: surface
  required property string message
  property string icon: "󰋼"
  property color tone: Color.muted
  Layout.fillWidth: true
  implicitHeight: messageRow.implicitHeight + Style.spacing.md * 2
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
    Text { Layout.fillWidth: true; text: surface.message; textFormat: Text.PlainText; color: Color.popups.text; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.body }
  }
}
