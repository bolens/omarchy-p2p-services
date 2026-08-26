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
  readonly property bool primaryFiltersWide: width >= Style.space(360)
  readonly property string serviceLayout: String(controller.setting("serviceLayout", "list"))
  readonly property string cardDensity: String(controller.setting("cardDensity", "comfortable"))
  function toggleLayout() { controller.persistKeepingOpen({serviceLayout: serviceLayout === "grid" ? "list" : "grid"}) }
  function cycleDensity() {
    controller.persistKeepingOpen({cardDensity: cardDensity === "comfortable" ? "compact" : (cardDensity === "compact" ? "minimal" : "comfortable")})
  }
  GridLayout {
    objectName: "primaryFilterGrid"
    Layout.fillWidth: true
    columns: filterBar.primaryFiltersWide ? filterBar.primaryFilterCount : 2
    columnSpacing: Style.spacing.sm
    rowSpacing: Style.spacing.sm
    P2PFilterPill { objectName: "primaryFilterPill"; Layout.fillWidth: true; controller: filterBar.controller; label: "All " + filterBar.controller.services.length; value: "all" }
    P2PFilterPill { objectName: "primaryFilterPill"; Layout.fillWidth: true; controller: filterBar.controller; label: "Running " + filterBar.controller.activeCount; value: "running" }
    P2PFilterPill { objectName: "primaryFilterPill"; Layout.fillWidth: true; controller: filterBar.controller; label: "Stopped " + filterBar.controller.stoppedCount; value: "stopped" }
    P2PFilterPill { objectName: "primaryFilterPill"; Layout.fillWidth: true; controller: filterBar.controller; label: "Issues " + filterBar.controller.errorCount; value: "issues"; visible: filterBar.controller.errorCount > 0 }
  }
  Flow {
    id: filterActions
    objectName: "filterActionRow"
    Layout.fillWidth: true
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
    text: filterBar.cardDensity.charAt(0).toUpperCase() + filterBar.cardDensity.slice(1)
    tooltipText: "Density: " + filterBar.cardDensity.charAt(0).toUpperCase() + filterBar.cardDensity.slice(1) + ". Switch to " + (filterBar.cardDensity === "comfortable" ? "compact" : (filterBar.cardDensity === "compact" ? "minimal" : "comfortable"))
    active: filterBar.cardDensity !== "comfortable"
    selected: active
    horizontalPadding: Style.spacing.controlGap
    onClicked: filterBar.cycleDensity()
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
