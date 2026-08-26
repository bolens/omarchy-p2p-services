import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
  id: heading
  property string title: ""
  property string description: ""
  Layout.fillWidth: true
  Layout.topMargin: 0
  spacing: 1
  RowLayout {
    Layout.fillWidth: true
    Text { objectName: "sectionHeadingTitle"; text: heading.title.toUpperCase(); textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 1.1 }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Util.alpha(Color.muted, 0.18) }
  }
  Text { objectName: "sectionHeadingDescription"; visible: heading.description !== ""; Layout.fillWidth: true; text: heading.description; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
}
