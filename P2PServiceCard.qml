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
  readonly property bool iconActions: compact || grid
  readonly property real cardPadding: minimal ? Style.spacing.xs : (compact ? Style.spacing.sm : Style.spacing.md)
  readonly property var compactIndicators: compact ? Model.compactIndicators(entry) : []
  readonly property var comfortableIndicators: !compact ? Model.comfortableIndicators(entry, controller.privacyFilter) : []
  readonly property real identityWidthHint: Math.min(serviceNameText.implicitWidth, Style.space(180))
  readonly property real headerWidthHint: serviceIcon.implicitWidth
    + identityWidthHint
    + serviceStatusBlock.implicitWidth + serviceHeaderRow.spacing * 2 + Style.spacing.lg
  readonly property real contentWidthHint: Math.max(headerWidthHint, serviceQuickActions.implicitWidth) + cardPadding * 2
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
    visible: controller.setting("showStatusRail", true) === true
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.margins: Style.space(3)
    width: Style.space(3)
    radius: width / 2
    color: controller.serviceColor(entry)
    opacity: entry.active || entry.hasError ? 0.9 : 0.28
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) controller.editService(entry.id)
      else if (mouse.button === Qt.RightButton) controller.toggleServiceContext(entry.id)
    }
  }
  HoverHandler {
    onHoveredChanged: {
      card.hovered = hovered
      if (hovered) controller.selectedServiceId = entry.id
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
        color: Util.alpha(controller.serviceColor(entry), 0.13)
        Text { anchors.centerIn: parent; text: controller.iconFor(entry); textFormat: Text.PlainText; color: controller.serviceColor(entry); font.family: Style.font.family; font.pixelSize: Style.font.icon }
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
            readonly property string fullLabel: controller.labelFor(entry)
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
          Text { visible: controller.setting("showFavoriteMarker", true) === true && controller.isFavorite(entry.id); text: "󰓎"; textFormat: Text.PlainText; color: controller.themeColor(String(controller.setting("favoriteColorRole","accent")), Color.accent); font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }
      RowLayout {
        id: serviceStatusBlock
        objectName: "serviceStatusBlock"
        spacing: Style.spacing.xs
        Repeater {
          model: card.compact && !card.grid ? card.compactIndicators : []
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
          indicator: ({icon:entry.hasError ? "󰅚" : (entry.active ? "󰐊" : "󰓛"),value:"",tooltip:(entry.hasError ? "Needs attention" : (entry.active ? "Running" : "Stopped")) + " · Show details",action:"details"})
          tone: controller.serviceColor(entry)
          horizontalPadding: Style.spacing.sm
          onTriggered: card.activateIndicator(indicator)
        }
        Text { objectName: "serviceStatusDot"; visible: !card.minimal && (!card.grid || card.density === "comfortable"); text: "●"; textFormat: Text.PlainText; color: controller.serviceColor(entry); font.family: Style.font.family; font.pixelSize: Style.font.caption }
        P2PLoadingIndicator {
          objectName: "serviceActionLoadingIndicator"
          running: controller.pendingService === entry.id
          compact: true
          label: controller.serviceActionLabel(entry.id)
          style: String(controller.setting("loadingIndicatorStyle", "spinner"))
          glyph: String(controller.setting("loadingIndicatorGlyph", ">"))
          speed: Number(controller.setting("loadingIndicatorSpeed", 140)) || 140
          tone: controller.serviceColor(entry)
        }
        Text { objectName: "serviceStatusText"; visible: controller.pendingService !== entry.id && !card.minimal && (!card.grid || card.density === "comfortable"); text: entry.active ? (entry.hasError ? "NEEDS ATTENTION" : "RUNNING") : "STOPPED"; textFormat: Text.PlainText; color: controller.serviceColor(entry); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 0.8 }
        P2PIndicatorPill {
          objectName: "backendIndicatorPill"
          visible: !card.grid && controller.setting("showBackendBadge", false) === true
          indicator: ({icon:"", value:String(entry.backend || "process").toUpperCase(), tooltip:controller.backendFilter === String(entry.backend || "process").toLowerCase() ? "Clear backend filter" : "Show " + String(entry.backend || "process") + " services", action:"backend"})
          tone: Color.muted
          onTriggered: card.activateIndicator(indicator)
        }
      }
    }

    Flow {
      id: comfortableMetadata
      objectName: "comfortableMetadata"
      visible: !card.compact && entry.active && controller.setting("showCardSummary", true) === true
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

    RowLayout {
      objectName: "gridMetadataRow"
      property int leadingInset: Style.spacing.xs
      visible: card.grid && card.density === "compact"
      Layout.fillWidth: true
      Layout.leftMargin: leadingInset
      spacing: Style.spacing.xs
      Repeater {
        model: card.grid && card.density === "compact" ? card.compactIndicators : []
        delegate: P2PIndicatorPill {
          objectName: "gridIndicatorPill"
          required property var modelData
          indicator: modelData
          tone: card.controller.serviceColor(card.entry)
          horizontalPadding: Style.spacing.md
          onTriggered: card.activateIndicator(indicator)
        }
      }
      Item { Layout.fillWidth: true }
      P2PIndicatorPill {
        objectName: "gridStatusPill"
        indicator: ({icon:"", value:entry.active ? (entry.hasError ? "ISSUE" : "RUNNING") : "STOPPED", tooltip:"Show service details", action:"details"})
        tone: controller.serviceColor(entry)
        onTriggered: card.activateIndicator(indicator)
      }
    }

    Text {
      visible: controller.setting("showTrafficStats", true) === true && entry.active && controller.trafficRate(entry.id, "active") === true
      Layout.fillWidth: true
      text: "↓ " + Model.formatRate(controller.trafficRate(entry.id, "rx")) + " · ↑ " + Model.formatRate(controller.trafficRate(entry.id, "tx"))
      textFormat: Text.PlainText
      color: controller.themeColor(String(controller.setting("activityColorRole","accent")), controller.serviceColor(entry))
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    RowLayout {
      id: serviceQuickActions
      objectName: "serviceQuickActions"
      visible: controller.setting("showQuickActions", true) === true && !card.minimal
      Layout.fillWidth: true
      Button { objectName: "servicePrimaryActionButton"; visible: entry.controllable !== false; text: card.iconActions ? "" : (entry.active ? "Stop" : "Start"); iconText: card.iconActions ? (entry.active ? "󰓛" : "󰐊") : ""; tooltipText: card.iconActions ? (entry.active ? "Stop service" : "Start service") : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; enabled: controller.pendingService === ""; onClicked: controller.act(entry, entry.active ? "stop" : "start") }
      Button { text: card.iconActions ? "" : "Restart"; iconText: card.iconActions ? "󰑐" : ""; tooltipText: card.iconActions ? "Restart service" : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; visible: entry.active && entry.controllable !== false; enabled: controller.pendingService === ""; onClicked: controller.act(entry, "restart") }
      Button { objectName: "serviceDetailsButton"; text: card.iconActions ? "" : (controller.expandedServiceId === entry.id ? "Hide details" : "Details"); iconText: card.iconActions ? (controller.expandedServiceId === entry.id ? "󰁈" : "󰁅") : ""; tooltipText: card.iconActions ? (controller.expandedServiceId === entry.id ? "Hide details" : "Show details") : ""; horizontalPadding: card.iconActions ? Style.spacing.controlGap : Style.spacing.controlPaddingX; active: controller.expandedServiceId === entry.id; selected: active; onClicked: controller.toggleServiceDetails(entry.id) }
      Item { Layout.fillWidth: true }
      Button { iconText: "󰖟"; tooltipText: "Open web console"; visible: controller.hasConsole(entry); horizontalPadding: Style.spacing.controlGap; onClicked: controller.openConsole(entry) }
      Button { iconText: "󰒓"; tooltipText: "Open configuration"; visible: entry.configExists && entry.controllable !== false; horizontalPadding: Style.spacing.controlGap; onClicked: controller.act(entry, "config") }
      Button { objectName: "serviceCustomizeButton"; iconText: "󰏫"; tooltipText: "Customize service"; horizontalPadding: Style.spacing.controlGap; onClicked: controller.editService(entry.id) }
    }
    Rectangle {
      objectName: "contextActionsSurface"
      visible: controller.contextServiceId === entry.id
      Layout.fillWidth: true
      implicitHeight: contextActions.implicitHeight + Style.spacing.sm * 2
      radius: Style.cornerRadius
      color: Util.alpha(controller.serviceColor(entry), 0.08)
      RowLayout {
        id: contextActions
        anchors.fill: parent
        anchors.margins: Style.spacing.sm
        spacing: Style.spacing.xs
        Button { text: controller.isFavorite(entry.id) ? "Unfavorite" : "Favorite"; onClicked: controller.toggleFavorite(entry.id) }
        Button { text: entry.active ? "Stop" : "Start"; visible: entry.controllable !== false; enabled: controller.pendingService === ""; onClicked: controller.act(entry, entry.active ? "stop" : "start") }
        Button { text: "Restart"; visible: entry.active && entry.controllable !== false; enabled: controller.pendingService === ""; onClicked: controller.act(entry, "restart") }
        Button { text: "Details"; onClicked: controller.toggleServiceDetails(entry.id) }
        Item { Layout.fillWidth: true }
        Button { iconText: "󰆍"; tooltipText: "Open service logs"; visible: entry.unit || entry.containerCount > 0; horizontalPadding: Style.spacing.controlGap; onClicked: controller.openLogs(entry) }
        Button { iconText: "󰆏"; tooltipText: "Copy privacy-aware diagnostics"; horizontalPadding: Style.spacing.controlGap; onClicked: controller.copyDiagnostics(entry) }
        Button { iconText: "󰖟"; tooltipText: "Open web console"; visible: controller.hasConsole(entry); horizontalPadding: Style.spacing.controlGap; onClicked: controller.openConsole(entry) }
        Button { iconText: "󰏫"; tooltipText: "Customize service"; horizontalPadding: Style.spacing.controlGap; onClicked: controller.editService(entry.id) }
      }
    }
    Rectangle { objectName: "serviceDetailsSeparator"; visible: controller.expandedServiceId === entry.id; Layout.fillWidth: true; implicitHeight: 1; color: Util.alpha(controller.serviceColor(entry), 0.16) }
    Item {
      objectName: "serviceExpandedDetails"
      property int horizontalInset: Style.spacing.sm
      visible: controller.expandedServiceId === entry.id
      Layout.fillWidth: true
      implicitHeight: expandedDetailsContent.implicitHeight
      ColumnLayout {
        id: expandedDetailsContent
        objectName: "serviceExpandedDetailsContent"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.horizontalInset
        anchors.rightMargin: parent.horizontalInset
        spacing: Style.spacing.xs
        Text {
        objectName: "serviceRuntimeDetailsText"
        visible: entry.active
        Layout.fillWidth: true
        text: controller.privacyFilter
          ? (entry.processCount + " process" + (entry.processCount === 1 ? "" : "es") + (entry.hasWeb ? " · Web console available" : ""))
          : ((entry.pids.length ? "PID: " + entry.pids.join(", ") : "PID: managed by " + (entry.unit || "an external launcher")) + "\nConfig: " + entry.config + (entry.endpoints.length ? "\n" + entry.endpoints.join("\n") : ""))
        textFormat: Text.PlainText
        color: Color.muted
        wrapMode: Text.WrapAnywhere
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
        Text {
        Layout.fillWidth: true
        text: entry.unit ? entry.unitScope + " service · " + entry.unit : "Managed by exact process name"
        textFormat: Text.PlainText
        color: Color.muted
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignRight
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
        Text {
        visible: entry.restartCount > 0 || entry.lastTransition || entry.failureReason
        Layout.fillWidth: true
        text: (entry.restartCount > 0 ? "Restarts: " + entry.restartCount : "No recorded restarts")
          + (entry.lastTransition ? " · changed " + entry.lastTransition : "")
          + (entry.failureReason ? "\nLast failure: " + entry.failureReason : "")
        textFormat: Text.PlainText
        color: entry.failureReason ? Color.urgent : Color.muted
        wrapMode: Text.WordWrap
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
