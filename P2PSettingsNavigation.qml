import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: navigation
  required property var controller
  readonly property bool wideTabs: width >= Style.space(540)
  Layout.fillWidth: true
  spacing: Style.spacing.md

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.sm
    Button { objectName: "settingsBackButton"; iconText: "󰁍"; tooltipText: "Back"; horizontalPadding: Style.spacing.controlGap; onClicked: navigation.controller.showingWidgetSettings = false }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)
      Text { Layout.fillWidth: true; text: "P2P Settings"; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.title; font.weight: Font.Bold }
      Text { Layout.fillWidth: true; text: navigation.controller.settingsPageDescription(); textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; font.letterSpacing: 1.1 }
    }
    P2PLoadingIndicator {
      objectName: "settingsSaveLoadingIndicator"
      running: navigation.controller.settingsSaveStatus === "saving"
      compact: true
      label: "SAVING"
      style: String(navigation.controller.setting("loadingIndicatorStyle", "spinner"))
      glyph: String(navigation.controller.setting("loadingIndicatorGlyph", ">"))
      speed: Number(navigation.controller.setting("loadingIndicatorSpeed", 140)) || 140
      tone: Color.accent
    }
    Text { objectName: "settingsSavedStatus"; visible: navigation.controller.settingsSaveStatus === "saved"; text: "✓ SAVED"; textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
  }

  PanelSeparator { Layout.fillWidth: true; foreground: navigation.controller.bar ? navigation.controller.bar.foreground : Color.popups.text }

  GridLayout {
    objectName: "settingsPageGrid"
    Layout.fillWidth: true
    columns: navigation.wideTabs ? 6 : 3
    rowSpacing: Style.spacing.sm
    columnSpacing: Style.spacing.sm
    Repeater {
      model: [
        {icon:"󰒓",label:"General",value:"general"},
        {icon:"󰏘",label:"Appearance",value:"appearance"},
        {icon:"󰓼",label:"Services",value:"services"},
        {icon:"󰾅",label:"Performance",value:"performance"},
        {icon:"󰀂",label:"Discovery",value:"discovery"},
        {icon:"󰏗",label:"Packages",value:"packages"}
      ]
      delegate: Button {
        required property var modelData
        objectName: "settingsPageButton-" + modelData.value
        Layout.fillWidth: true
        text: modelData.icon + "  " + modelData.label
        active: navigation.controller.settingsPage === modelData.value
        selected: active
        bordered: true
        fontSize: Style.font.bodySmall
        horizontalPadding: navigation.wideTabs ? Style.spacing.controlGap : Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: navigation.controller.showSettingsPage(modelData.value)
      }
    }
  }
}
