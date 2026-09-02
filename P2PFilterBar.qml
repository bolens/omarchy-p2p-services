pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: filterBar
  required property var controller

  objectName: "serviceFilterBar"
  Layout.fillWidth: true
  spacing: Style.spacing.sm
  readonly property int primaryFilterCount: controller.errorCount > 0 ? 4 : 3
  readonly property string serviceLayout: String(controller.setting("serviceLayout", "list"))
  readonly property string cardDensity: String(controller.setting("cardDensity", "comfortable"))
  function toggleLayout() { controller.persistKeepingOpen({serviceLayout: serviceLayout === "grid" ? "list" : "grid"}) }
  function cycleDensity() {
    controller.persistKeepingOpen({cardDensity: cardDensity === "comfortable" ? "compact" : (cardDensity === "compact" ? "minimal" : "comfortable")})
  }
  Item {
    id: filterToolbar
    objectName: "filterToolbar"
    Layout.fillWidth: true
    readonly property bool singleRow: width >= primaryFilters.width + filterActions.width + Style.spacing.sm
    implicitHeight: singleRow ? Math.max(primaryFilters.height, filterActions.height) : primaryFilters.height + Style.spacing.sm + filterActions.height
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Row {
      id: primaryFilters
      objectName: "primaryFilterFlow"
      x: 0
      y: 0
      spacing: Style.spacing.sm
      P2PFilterPill { objectName: "primaryFilterPill"; controller: filterBar.controller; label: "All services"; value: "all"; icon: "󰒍"; count: String(filterBar.controller.services.length) }
      P2PFilterPill { objectName: "primaryFilterPill"; controller: filterBar.controller; label: "Running services"; value: "running"; icon: "󰐊"; count: String(filterBar.controller.activeCount) }
      P2PFilterPill { objectName: "primaryFilterPill"; controller: filterBar.controller; label: "Stopped services"; value: "stopped"; icon: "󰓛"; count: String(filterBar.controller.stoppedCount) }
      P2PFilterPill { objectName: "primaryFilterPill"; controller: filterBar.controller; label: "Services needing attention"; value: "issues"; icon: "󰅚"; count: String(filterBar.controller.errorCount); visible: filterBar.controller.errorCount > 0 }
    }
    Row {
      id: filterActions
      objectName: "filterActionRow"
      x: Math.max(0, filterToolbar.width - width)
      y: filterToolbar.singleRow ? 0 : primaryFilters.height + Style.spacing.sm
      spacing: Style.spacing.sm
  Button {
    objectName: "serviceLayoutToggle"
    width: implicitWidth
    height: implicitHeight
    iconText: filterBar.serviceLayout === "grid" ? "󰉹" : "󰕰"
    tooltipText: filterBar.serviceLayout === "grid" ? "Switch to single-column list" : "Switch to two-column grid"
    active: filterBar.serviceLayout === "grid"
    selected: active
    horizontalPadding: Style.spacing.controlGap
    onClicked: filterBar.toggleLayout()
  }
  Button {
    objectName: "cardDensityToggle"
    width: implicitWidth
    height: implicitHeight
    iconText: filterBar.cardDensity === "comfortable" ? "▤" : (filterBar.cardDensity === "compact" ? "☷" : "⋯")
    tooltipText: "Density: " + filterBar.cardDensity.charAt(0).toUpperCase() + filterBar.cardDensity.slice(1) + ". Switch to " + (filterBar.cardDensity === "comfortable" ? "compact" : (filterBar.cardDensity === "compact" ? "minimal" : "comfortable"))
    active: filterBar.cardDensity !== "comfortable"
    selected: active
    horizontalPadding: Style.spacing.controlGap
    onClicked: filterBar.cycleDensity()
  }
  Button {
    objectName: "serviceGroupsCollapseToggle"
    width: implicitWidth
    height: implicitHeight
    visible: filterBar.controller.serviceGroupsVisible === true
    iconText: filterBar.controller.allServiceGroupsCollapsed === true ? "▾" : "▴"
    tooltipText: filterBar.controller.allServiceGroupsCollapsed === true ? "Expand all service groups" : "Collapse all service groups"
    horizontalPadding: Style.spacing.controlGap
    onClicked: filterBar.controller.setAllServiceGroupsCollapsed(filterBar.controller.allServiceGroupsCollapsed !== true)
  }
  P2PIndicatorPill {
    objectName: "activeBackendFilterPill"
    width: implicitWidth
    height: implicitHeight
    visible: filterBar.controller.backendFilter !== ""
    indicator: ({icon:"",value:filterBar.controller.backendFilter.toUpperCase(),tooltip:"Clear backend filter"})
    tone: Color.bar.active
    onTriggered: filterBar.controller.filterByBackend(filterBar.controller.backendFilter)
  }
  Rectangle {
    objectName: "visibleServiceCountBadge"
    width: implicitWidth
    height: implicitHeight
    visible: filterBar.controller.serviceFilter !== "all" || filterBar.controller.searchQuery !== "" || filterBar.controller.backendFilter !== ""
    implicitWidth: visibleServiceCountText.implicitWidth + Style.spacing.sm * 2
    implicitHeight: visibleServiceCountText.implicitHeight + Style.space(4)
    radius: implicitHeight / 2
    color: Util.alpha(Color.muted, 0.14)
    border.width: 1
    border.color: Util.alpha(Color.muted, 0.24)
    Text {
      id: visibleServiceCountText
      objectName: "visibleServiceCountText"
      anchors.centerIn: parent
      text: filterBar.controller.visibleServices.length + " SHOWN"
      textFormat: Text.PlainText
      color: Color.popups.text
      opacity: 0.68
      font.family: Style.font.mono || Style.font.family
      font.pixelSize: Style.font.caption
      font.weight: Font.Bold
      font.letterSpacing: 0.8
    }
    }
  }
  }
}
