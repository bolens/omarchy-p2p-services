import QtQuick
import QtQuick.Layouts
import qs.Commons

GridLayout {
  id: grid
  objectName: "settingsFieldGrid"
  property int wideColumns: 2
  readonly property bool twoColumns: width >= Style.space(520)

  Layout.fillWidth: true
  columns: twoColumns ? Math.max(2, wideColumns) : 1
  columnSpacing: Style.spacing.md
  rowSpacing: Style.spacing.sm
}
