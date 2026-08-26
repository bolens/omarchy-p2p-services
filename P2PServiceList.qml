import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: list
  required property var controller
  readonly property bool gridView: controller.setting("serviceLayout", "list") === "grid"
  readonly property bool twoColumnGrid: gridView && width >= Style.space(360)
  readonly property int columns: twoColumnGrid ? 2 : 1
  readonly property int gridSectionCount: gridSections.count
  readonly property string density: String(controller.setting("cardDensity", "comfortable"))
  readonly property real gridColumnSpacing: density === "minimal" ? Style.spacing.xs : Style.spacing.sm
  readonly property real serviceRowSpacing: density === "comfortable" ? Style.spacing.md : (density === "compact" ? Style.spacing.sm : Style.spacing.xs)
  readonly property var gridGroups: {
    var groups = [], services = controller.visibleServices || []
    for (var index = 0; index < services.length; index++) {
      var entry = services[index]
      var name = controller.groupLabelFor(entry)
      var group = groups.length ? groups[groups.length - 1] : null
      if (!group || group.name !== name) {
        group = {name:name, firstIndex:index, firstEntry:entry, entries:[]}
        groups.push(group)
      }
      group.entries.push(entry)
    }
    return groups
  }
  readonly property real contentWidthHint: {
    var instantiatedCount = gridView ? gridSections.count : listRows.count
    var hint = 0, services = controller.visibleServices || []
    for (var index = 0; index < services.length; index++) {
      var item = itemAt(index)
      if (item) hint = Math.max(hint, Number(item.contentWidthHint) || 0)
    }
    if (!gridView) return hint
    return services.length > 1 ? hint * 2 + gridColumnSpacing : hint
  }

  Layout.fillWidth: true
  spacing: serviceRowSpacing

  function itemAt(index) {
    if (!gridView) return listRows.itemAt(index)
    var offset = 0
    for (var groupIndex = 0; groupIndex < gridSections.count; groupIndex++) {
      var section = gridSections.itemAt(groupIndex)
      if (!section) continue
      if (index < offset + section.serviceCount) return section.itemAt(index - offset)
      offset += section.serviceCount
    }
    return null
  }
  function itemForId(serviceId) {
    var services = controller.visibleServices || []
    for (var index = 0; index < services.length; index++) {
      if (services[index].id === serviceId) return itemAt(index)
    }
    return null
  }

  Repeater {
    id: listRows
    model: !list.gridView && list.controller.editingServiceId === "" && !list.controller.showingWidgetSettings ? list.controller.visibleServices : null
    delegate: ColumnLayout {
      id: listDelegate
      required property var modelData
      required property int index
      readonly property string groupName: list.controller.groupLabelFor(modelData)
      readonly property real contentWidthHint: serviceCard.contentWidthHint
      Layout.fillWidth: true
      spacing: Style.spacing.xs
      P2PGroupHeader { layoutVisible: true; controller: list.controller; entry: listDelegate.modelData; serviceIndex: listDelegate.index; groupName: listDelegate.groupName }
      P2PServiceCard { id: serviceCard; visible: !list.controller.isGroupCollapsed(listDelegate.groupName); Layout.fillWidth: true; entry: listDelegate.modelData; controller: list.controller }
    }
  }

  Repeater {
    id: gridSections
    model: list.gridView && list.controller.editingServiceId === "" && !list.controller.showingWidgetSettings ? list.gridGroups : null
    delegate: ColumnLayout {
      id: gridSection
      required property var modelData
      readonly property int serviceCount: modelData.entries.length
      Layout.fillWidth: true
      spacing: Style.spacing.xs
      function itemAt(index) { return gridCards.itemAt(index) }

      P2PGroupHeader {
        objectName: "gridGroupHeader"
        layoutVisible: list.controller.setting("serviceGroupMode", "none") !== "none"
        controller: list.controller
        entry: gridSection.modelData.firstEntry
        serviceIndex: gridSection.modelData.firstIndex
        groupName: gridSection.modelData.name
      }
      GridLayout {
        Layout.fillWidth: true
        columns: list.twoColumnGrid ? 2 : 1
        columnSpacing: list.gridColumnSpacing
        rowSpacing: list.serviceRowSpacing
        Repeater {
          id: gridCards
          model: list.controller.isGroupCollapsed(gridSection.modelData.name) ? null : gridSection.modelData.entries
          delegate: P2PServiceCard {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: list.twoColumnGrid ? Math.max(Style.space(160), (list.width - list.gridColumnSpacing) / 2) : list.width
            entry: modelData
            controller: list.controller
          }
        }
      }
    }
  }
}
