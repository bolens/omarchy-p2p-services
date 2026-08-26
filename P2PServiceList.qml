import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

GridLayout {
  id: list
  required property var controller
  readonly property bool gridView: controller.setting("serviceLayout", "list") === "grid"
  readonly property bool twoColumnGrid: gridView && width >= Style.space(520)
  columns: twoColumnGrid ? 2 : 1
  readonly property string density: String(controller.setting("cardDensity", "comfortable"))
  columnSpacing: density === "minimal" ? Style.spacing.xs : Style.spacing.sm
  rowSpacing: density === "comfortable" ? Style.spacing.md : (density === "compact" ? Style.spacing.sm : Style.spacing.xs)
  readonly property real contentWidthHint: {
    var hint = 0, count = rows.count
    for (var index = 0; index < count; index++) {
      var item = rows.itemAt(index)
      if (item) hint = Math.max(hint, Number(item.cardWidthHint) || 0)
    }
    return hint
  }

  function itemAt(index) { return rows.itemAt(index) }
  function itemForId(serviceId) {
    for (var index = 0; index < rows.count; index++) {
      var item = rows.itemAt(index)
      if (item && item.modelData && item.modelData.id === serviceId) return item
    }
    return null
  }

  Repeater {
    id: rows
    model: list.controller.editingServiceId === "" && !list.controller.showingWidgetSettings ? list.controller.visibleServices : null
    delegate: Item {
      id: serviceDelegate
      required property var modelData
      required property int index
      readonly property string groupName: list.controller.groupLabelFor(modelData)
      readonly property real cardWidthHint: serviceCard.contentWidthHint
      Layout.fillWidth: true
      Layout.preferredWidth: list.twoColumnGrid ? Math.max(Style.space(200), (list.width - list.columnSpacing) / 2) : list.width
      implicitHeight: serviceDelegateColumn.implicitHeight
      ColumnLayout {
        id: serviceDelegateColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.xs
        P2PGroupHeader { layoutVisible: !list.gridView; controller: list.controller; entry: serviceDelegate.modelData; serviceIndex: serviceDelegate.index; groupName: serviceDelegate.groupName }
        P2PServiceCard { id: serviceCard; visible: !list.controller.isGroupCollapsed(serviceDelegate.groupName); Layout.fillWidth: true; entry: serviceDelegate.modelData; controller: list.controller }
      }
    }
  }
}
