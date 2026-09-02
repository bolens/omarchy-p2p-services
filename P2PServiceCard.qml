pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Rectangle {
  id: card
  objectName: "serviceCard"
  // External Repeater delegates apply caller bindings after construction in
  // this shell build, so a `required` object role fails before `modelData` is
  // assigned. Keep construction safe, then let the delegate binding replace it.
  property var entry: ({id: "", name: "", icon: "", active: false, hasError: false, pids: [], endpoints: []})
  required property var controller
  property bool hovered: false

  Layout.fillWidth: true
  readonly property string density: String(controller.setting("cardDensity", "comfortable"))
  readonly property bool grid: controller.setting("serviceLayout", "list") === "grid"
  readonly property bool compact: density !== "comfortable"
  readonly property bool minimal: density === "minimal"
  readonly property bool minimalList: minimal && !grid
  readonly property bool iconActions: compact
  readonly property real cardPadding: minimal ? Style.spacing.xs : (compact ? Style.spacing.sm : Style.spacing.md)
  readonly property var compactIndicators: compact ? Model.compactIndicators(entry) : []
  readonly property var comfortableIndicators: !compact ? Model.comfortableIndicators(entry, controller.privacyFilter) : []
  readonly property real identityWidthHint: Math.min(serviceNameText.implicitWidth, Style.space(180))
  readonly property real headerWidthHint: serviceIcon.implicitWidth
    + identityWidthHint
    + serviceStatusBlock.implicitWidth + serviceHeaderRow.spacing * 2 + Style.spacing.lg
  readonly property real contentWidthHint: Math.max(
    headerWidthHint,
    serviceQuickActions.visible ? serviceQuickActions.implicitWidth : 0
  ) + cardPadding * 2
  function activateIndicator(indicator) {
    if (indicator.action === "console") controller.openConsole(entry)
    else if (indicator.action === "config") controller.act(entry, "config")
    else if (indicator.action === "backend") controller.filterByBackend(String(entry.backend || "process"))
    else controller.toggleServiceDetails(entry.id)
  }
  implicitHeight: serviceColumn.implicitHeight + cardPadding * 2
  radius: Style.cornerRadius
  color: Util.alpha(controller.serviceColor(entry), controller.selectedServiceId === entry.id ? 0.13 : (hovered ? 0.09 : (entry.active ? 0.065 : 0.025)))
  border.width: controller.selectedServiceId === entry.id ? 2 : 1
  border.color: Util.alpha(controller.serviceColor(entry), controller.selectedServiceId === entry.id ? 0.7 : (entry.active ? 0.32 : 0.12))

  Rectangle {
    visible: card.controller.setting("showStatusRail", true) === true
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(3)
    width: Style.space(3)
    radius: width / 2
    color: card.controller.serviceColor(card.entry)
    opacity: card.entry.active || card.entry.hasError ? 0.9 : 0.28
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) card.controller.editService(card.entry.id)
      else if (mouse.button === Qt.RightButton) card.controller.toggleServiceContext(card.entry.id)
    }
  }
  HoverHandler {
    onHoveredChanged: {
      card.hovered = hovered
      if (hovered) card.controller.selectedServiceId = card.entry.id
    }
  }

  ColumnLayout {
    id: serviceColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: card.cardPadding
    spacing: card.compact ? Style.spacing.xs : Style.spacing.sm

    RowLayout {
      id: serviceHeaderRow
      Layout.fillWidth: true
      Rectangle {
        id: serviceIcon
        implicitWidth: Style.space(card.minimal ? 26 : (card.compact ? 30 : 36))
        implicitHeight: Style.space(card.minimal ? 26 : (card.compact ? 30 : 36))
        radius: Style.cornerRadius
        color: Util.alpha(card.controller.serviceColor(card.entry), 0.13)
        Text { anchors.centerIn: parent; text: String(card.controller.iconFor(card.entry) || ""); textFormat: Text.PlainText; color: card.controller.serviceColor(card.entry); font.family: Style.font.family; font.pixelSize: Style.font.icon }
      }
      ColumnLayout {
        objectName: "serviceIdentityBlock"
        Layout.fillWidth: true
        Layout.maximumWidth: Style.space(1000)
        spacing: 1
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.xs
          Text {
            id: serviceNameText
            objectName: "serviceNameText"
            readonly property string fullLabel: card.controller.labelFor(card.entry)
            Layout.fillWidth: true
            text: fullLabel
            textFormat: Text.PlainText
            color: Color.popups.text
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            HoverHandler { id: serviceNameHover }
            ToolTip.visible: serviceNameText.truncated && serviceNameHover.hovered
            ToolTip.text: serviceNameText.fullLabel
          }
          Text { visible: card.controller.setting("showFavoriteMarker", true) === true && card.controller.isFavorite(card.entry.id); text: "󰓎"; textFormat: Text.PlainText; color: card.controller.themeColor(String(card.controller.setting("favoriteColorRole","accent")), Color.accent); font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }
      RowLayout {
        id: serviceStatusBlock
        objectName: "serviceStatusBlock"
        spacing: Style.spacing.xs
        Repeater {
          model: card.compact && (!card.grid || card.density === "compact") ? card.compactIndicators : []
          delegate: P2PIndicatorPill {
            objectName: "compactIndicatorPill"
            required property var modelData
            indicator: modelData
            tone: card.controller.serviceColor(card.entry)
            onTriggered: card.activateIndicator(indicator)
          }
        }
        P2PIndicatorPill {
          objectName: "minimalStatusPill"
          visible: card.minimal
          indicator: ({icon:card.entry.hasError ? "󰅚" : (card.entry.active ? "󰐊" : "󰓛"),value:"",tooltip:(card.entry.hasError ? "Needs attention" : (card.entry.active ? "Running" : "Stopped")) + " · Show details",action:"details"})
          tone: card.controller.serviceColor(card.entry)
          horizontalPadding: Style.spacing.sm
          onTriggered: card.activateIndicator(indicator)
        }
        P2PIndicatorPill {
          objectName: "gridStatusPill"
          visible: card.grid && card.density === "compact"
          indicator: ({icon:"", value:card.entry.active ? (card.entry.hasError ? "ISSUE" : "RUNNING") : "STOPPED", tooltip:"Show service details", action:"details"})
          tone: card.controller.serviceColor(card.entry)
          onTriggered: card.activateIndicator(indicator)
        }
        Text { objectName: "serviceStatusDot"; visible: !card.minimal && (!card.grid || card.density === "comfortable"); text: "●"; textFormat: Text.PlainText; color: card.controller.serviceColor(card.entry); font.family: Style.font.family; font.pixelSize: Style.font.caption }
        P2PLoadingIndicator {
          objectName: "serviceActionLoadingIndicator"
          running: card.controller.pendingService === card.entry.id
          animationEnabled: card.visible && card.controller.opened !== false && card.controller.setting("animateLoadingIndicators", true) === true
          compact: true
          label: card.controller.serviceActionLabel(card.entry.id)
          style: String(card.controller.setting("loadingIndicatorStyle", "spinner"))
          glyph: String(card.controller.setting("loadingIndicatorGlyph", ">"))
          speed: Number(card.controller.setting("loadingIndicatorSpeed", 140)) || 140
          tone: card.controller.serviceColor(card.entry)
        }
        Text { objectName: "serviceStatusText"; visible: card.controller.pendingService !== card.entry.id && !card.minimal && (!card.grid || card.density === "comfortable"); text: card.entry.active ? (card.entry.hasError ? "NEEDS ATTENTION" : "RUNNING") : "STOPPED"; textFormat: Text.PlainText; color: card.controller.serviceColor(card.entry); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 0.8 }
        P2PIndicatorPill {
          objectName: "backendIndicatorPill"
          visible: card.controller.setting("showBackendBadge", false) === true
          indicator: ({icon:"", value:String(card.entry.backend || "process").toUpperCase(), tooltip:card.controller.backendFilter === String(card.entry.backend || "process").toLowerCase() ? "Clear backend filter" : "Show " + String(card.entry.backend || "process") + " services", action:"backend"})
          tone: Color.muted
          onTriggered: card.activateIndicator(indicator)
        }
      }
    }

    Flow {
      id: comfortableMetadata
      objectName: "comfortableMetadata"
      visible: !card.compact && card.entry.active && card.controller.setting("showCardSummary", true) === true
      Layout.fillWidth: true
      spacing: Style.spacing.xs
      Repeater {
        model: comfortableMetadata.visible ? card.comfortableIndicators : []
        delegate: P2PIndicatorPill {
          objectName: "comfortableIndicatorPill"
          required property var modelData
          indicator: modelData
          tone: card.controller.serviceColor(card.entry)
          horizontalPadding: Style.spacing.md
          onTriggered: card.activateIndicator(indicator)
        }
      }
    }

    Text {
      visible: card.controller.setting("showTrafficStats", true) === true && card.entry.active && card.controller.trafficRate(card.entry.id, "active") === true
      Layout.fillWidth: true
      text: "↓ " + Model.formatRate(card.controller.trafficRate(card.entry.id, "rx")) + " · ↑ " + Model.formatRate(card.controller.trafficRate(card.entry.id, "tx"))
      textFormat: Text.PlainText
      color: card.controller.themeColor(String(card.controller.setting("activityColorRole","accent")), card.controller.serviceColor(card.entry))
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    RowLayout {
      id: serviceQuickActions
      objectName: "serviceQuickActions"
      visible: card.controller.setting("showQuickActions", true) === true && !card.minimal
      Layout.fillWidth: true
      Button { objectName: "servicePrimaryActionButton"; visible: card.entry.controllable !== false; text: card.iconActions ? "" : (card.entry.active ? "Stop" : "Start"); iconText: card.iconActions ? (card.entry.active ? "󰓛" : "󰐊") : ""; tooltipText: card.iconActions ? (card.entry.active ? "Stop service" : "Start service") : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; enabled: card.controller.pendingService === ""; onClicked: card.controller.act(card.entry, card.entry.active ? "stop" : "start") }
      Button { text: card.iconActions ? "" : "Restart"; iconText: card.iconActions ? "󰑐" : ""; tooltipText: card.iconActions ? "Restart service" : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; visible: card.entry.active && card.entry.controllable !== false; enabled: card.controller.pendingService === ""; onClicked: card.controller.act(card.entry, "restart") }
      Button { objectName: "serviceDetailsButton"; text: card.iconActions ? "" : (card.controller.expandedServiceId === card.entry.id ? "Hide details" : "Details"); iconText: card.iconActions ? (card.controller.expandedServiceId === card.entry.id ? "󰁈" : "󰁅") : ""; tooltipText: card.iconActions ? (card.controller.expandedServiceId === card.entry.id ? "Hide details" : "Show details") : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; active: card.controller.expandedServiceId === card.entry.id; selected: active; onClicked: card.controller.toggleServiceDetails(card.entry.id) }
      Item { Layout.fillWidth: true }
      Button { iconText: "󰖟"; tooltipText: "Open web console"; visible: card.controller.hasConsole(card.entry); horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.openConsole(card.entry) }
      Button { iconText: "󰒓"; tooltipText: "Open configuration"; visible: card.entry.configExists === true && card.entry.controllable !== false; horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.act(card.entry, "config") }
      Button { objectName: "serviceCustomizeButton"; iconText: "󰏫"; tooltipText: "Customize service"; horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.editService(card.entry.id) }
    }
    Rectangle {
      objectName: "contextActionsSurface"
      visible: card.controller.contextServiceId === card.entry.id
      Layout.fillWidth: true
      implicitHeight: contextActions.implicitHeight + Style.spacing.sm * 2
      radius: Style.cornerRadius
      color: Util.alpha(card.controller.serviceColor(card.entry), 0.08)
      RowLayout {
        id: contextActions
        anchors.fill: parent
        anchors.margins: Style.spacing.sm
        spacing: Style.spacing.xs
        Button { text: card.controller.isFavorite(card.entry.id) ? "Unfavorite" : "Favorite"; onClicked: card.controller.toggleFavorite(card.entry.id) }
        Button { text: card.entry.active ? "Stop" : "Start"; visible: card.entry.controllable !== false; enabled: card.controller.pendingService === ""; onClicked: card.controller.act(card.entry, card.entry.active ? "stop" : "start") }
        Button { text: "Restart"; visible: card.entry.active && card.entry.controllable !== false; enabled: card.controller.pendingService === ""; onClicked: card.controller.act(card.entry, "restart") }
        Button { text: "Details"; onClicked: card.controller.toggleServiceDetails(card.entry.id) }
        Item { Layout.fillWidth: true }
        Button { iconText: "󰆍"; tooltipText: "Open service logs"; visible: card.entry.unit || card.entry.containerCount > 0; horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.openLogs(card.entry) }
        Button { iconText: "󰆏"; tooltipText: "Copy privacy-aware diagnostics"; horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.copyDiagnostics(card.entry) }
        Button { iconText: "󰖟"; tooltipText: "Open web console"; visible: card.controller.hasConsole(card.entry); horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.openConsole(card.entry) }
        Button { iconText: "󰏫"; tooltipText: "Customize service"; horizontalPadding: Style.spacing.controlGap; onClicked: card.controller.editService(card.entry.id) }
      }
    }
    Rectangle { objectName: "serviceDetailsSeparator"; visible: card.controller.expandedServiceId === card.entry.id; Layout.fillWidth: true; implicitHeight: 1; color: Util.alpha(card.controller.serviceColor(card.entry), 0.16) }
    Rectangle {
      objectName: "serviceExpandedDetails"
      property int horizontalInset: Style.spacing.sm
      visible: card.controller.expandedServiceId === card.entry.id
      Layout.fillWidth: true
      implicitHeight: expandedDetailsContent.implicitHeight + Style.spacing.sm * 2
      radius: Style.cornerRadius
      color: Util.alpha(card.controller.serviceColor(card.entry), 0.045)
      border.width: 1
      border.color: Util.alpha(card.controller.serviceColor(card.entry), 0.12)
      ColumnLayout {
        id: expandedDetailsContent
        objectName: "serviceExpandedDetailsContent"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: parent.horizontalInset
        anchors.rightMargin: parent.horizontalInset
        anchors.topMargin: Style.spacing.sm
        spacing: Style.spacing.xs
        Text {
        objectName: "serviceRuntimeDetailsText"
        visible: card.entry.active
        Layout.fillWidth: true
        text: card.controller.privacyFilter
          ? (card.entry.processCount + " process" + (card.entry.processCount === 1 ? "" : "es") + (card.entry.hasWeb ? " · Web console available" : ""))
          : ((card.entry.pids.length ? "PID: " + card.entry.pids.join(", ") : "PID: managed by " + (card.entry.unit || "an external launcher")) + "\nConfig: " + card.entry.config + (card.entry.endpoints.length ? "\n" + card.entry.endpoints.join("\n") : ""))
        textFormat: Text.PlainText
        color: Color.muted
        wrapMode: Text.WrapAnywhere
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
        Text {
        Layout.fillWidth: true
        text: card.entry.unit ? card.entry.unitScope + " service · " + card.entry.unit : "Managed by exact process name"
        textFormat: Text.PlainText
        color: Color.muted
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignRight
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
        Text {
        visible: Number(card.entry.restartCount) > 0 || String(card.entry.lastTransition || "") !== "" || String(card.entry.failureReason || "") !== ""
        Layout.fillWidth: true
        text: (card.entry.restartCount > 0 ? "Restarts: " + card.entry.restartCount : "No recorded restarts")
          + (card.entry.lastTransition ? " · changed " + card.entry.lastTransition : "")
          + (card.entry.failureReason ? "\nLast failure: " + card.entry.failureReason : "")
        textFormat: Text.PlainText
        color: card.entry.failureReason ? Color.urgent : Color.muted
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
