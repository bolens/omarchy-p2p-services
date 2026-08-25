import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "discovery"
  Layout.fillWidth: true
  spacing: Style.spacing.md
          P2PSectionHeading { title: "Console routing"; description: "Choose the fallback host used for discovered container consoles." }
          SettingsSurface {
          Text { text: "Global console host"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { Layout.fillWidth: true; text: "Used with published container ports when no reverse-proxy URL is discovered. Leave empty for 127.0.0.1."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            TextField { id: consoleHostEditor; objectName: "consoleHostEditor"; Layout.fillWidth: true; placeholderText: "server.home.arpa or 192.168.1.10"; text: String(page.controller.setting("consoleHost", "")); foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: page.controller.persistKeepingOpen({consoleHost: text.trim()}) }
            Button { text: "Save"; onClicked: page.controller.persistKeepingOpen({consoleHost: consoleHostEditor.text.trim()}) }
          }
          }

          P2PSectionHeading { title: "Service filtering"; description: "Limit the widget to selected detected backend IDs." }
          SettingsSurface {
          Text { Layout.fillWidth: true; text: "Comma-separated backend IDs. Leave empty to show every detected service."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            TextField { id: serviceAllowlistEditor; objectName: "serviceAllowlistEditor"; Layout.fillWidth: true; placeholderText: "yggdrasil, i2pd, syncthing"; text: Model.enabled(page.controller.setting("enabledServices", []), []).join(", "); foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family }
            Button { objectName: "serviceAllowlistSaveButton"; text: "Save"; onClicked: { var ids = serviceAllowlistEditor.text.split(",").map(function(value) { return value.trim() }).filter(function(value) { return value !== "" }); page.controller.persistKeepingOpen({enabledServices: ids}) } }
          }
          }

          P2PSectionHeading { title: "Custom services"; description: "Add strictly validated process or systemd-backed services." }
          SettingsSurface {
          Text { Layout.fillWidth: true; text: "JSON array; IDs must begin custom-. Custom services are observation-only: executable, process, and systemd names support detection but cannot be started, stopped, restarted, or edited."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            TextField { id: customServicesEditor; objectName: "customServicesEditor"; Layout.fillWidth: true; placeholderText: "[]"; text: JSON.stringify(page.controller.setting("customServices", [])); foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family }
            Button { objectName: "customServicesSaveButton"; text: "Validate & save"; onClicked: page.controller.saveCustomServices(customServicesEditor.text) }
          }
          }

          P2PSectionHeading { title: "Settings data"; description: "Transfer durable settings or restore the previous snapshot." }
          SettingsSurface {
          P2PLoadingIndicator {
            objectName: "settingsTransferLoadingIndicator"
            running: page.controller.settingsTransferLoading
            label: page.controller.settingsTransferLabel()
            style: String(page.controller.setting("loadingIndicatorStyle", "spinner"))
            glyph: String(page.controller.setting("loadingIndicatorGlyph", ">"))
            speed: Number(page.controller.setting("loadingIndicatorSpeed", 140)) || 140
            tone: page.controller.themeColor("accent", Color.accent)
          }
          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "settingsExportButton"; text: "Export settings"; enabled: !page.controller.settingsTransferRunning; onClicked: page.controller.exportSettings() }
            Button { objectName: "settingsImportButton"; text: "Import settings"; enabled: !page.controller.settingsTransferRunning; tooltipText: "Import the previously exported settings file"; onClicked: page.controller.importSettings() }
            Button { objectName: "settingsUndoButton"; text: "Undo last change"; enabled: !page.controller.settingsTransferRunning; tooltipText: "Restore the previous durable settings snapshot"; onClicked: page.controller.undoSettings() }
            Item { Layout.fillWidth: true }
          }
          }
}
