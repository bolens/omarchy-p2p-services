import QtQuick
import QtQuick.Layouts
import qs.Commons

Flow {
  id: filterBar
  required property var controller

  objectName: "serviceFilterBar"
  Layout.fillWidth: true
  spacing: Style.spacing.sm
  readonly property int primaryFilterCount: controller.errorCount > 0 ? 4 : 3
  readonly property real primaryFilterWidth: Math.max(0, (width - spacing * (primaryFilterCount - 1)) / primaryFilterCount)
  onWidthChanged: forceLayout()

  P2PFilterPill { objectName: "primaryFilterPill"; width: Math.max(implicitWidth, filterBar.primaryFilterWidth); height: implicitHeight; controller: filterBar.controller; label: "All " + filterBar.controller.services.length; value: "all" }
  P2PFilterPill { objectName: "primaryFilterPill"; width: Math.max(implicitWidth, filterBar.primaryFilterWidth); height: implicitHeight; controller: filterBar.controller; label: "Running " + filterBar.controller.activeCount; value: "running" }
  P2PFilterPill { objectName: "primaryFilterPill"; width: Math.max(implicitWidth, filterBar.primaryFilterWidth); height: implicitHeight; controller: filterBar.controller; label: "Stopped " + filterBar.controller.stoppedCount; value: "stopped" }
  P2PFilterPill { objectName: "primaryFilterPill"; width: Math.max(implicitWidth, filterBar.primaryFilterWidth); height: implicitHeight; controller: filterBar.controller; label: "Issues " + filterBar.controller.errorCount; value: "issues"; visible: filterBar.controller.errorCount > 0 }
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
