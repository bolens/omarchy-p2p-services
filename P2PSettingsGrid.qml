import QtQuick
import QtQuick.Layouts
import qs.Commons

GridLayout {
  id: grid
  objectName: "settingsFieldGrid"
  readonly property bool twoColumns: width >= Style.space(520)

  Layout.fillWidth: true
  columns: twoColumns ? 2 : 1
  columnSpacing: Style.spacing.md
  rowSpacing: Style.spacing.sm
}
