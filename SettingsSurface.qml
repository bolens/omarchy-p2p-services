pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: surface
  default property alias content: surfaceColumn.data
  property color accent: Color.muted

  Layout.fillWidth: true
  implicitHeight: surfaceColumn.implicitHeight + Style.spacing.sm * 2
  radius: Style.cornerRadius
  color: Util.alpha(accent, 0.035)
  border.width: 1
  border.color: Util.alpha(accent, 0.13)

  ColumnLayout {
    id: surfaceColumn
    anchors.fill: parent
    anchors.margins: Style.spacing.sm
    spacing: Style.spacing.sm
  }
}
