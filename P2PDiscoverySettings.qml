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
  function sectionY(section) { return section === "custom-services" ? customHeading.y : section === "routing" ? routingHeading.y : -1 }
          P2PSectionHeading { id: routingHeading; title: "Console routing"; description: "Fallback routing for published container consoles." }
          SettingsSurface {
          Text { text: "Fallback console host · blank uses 127.0.0.1"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            TextField { id: consoleHostEditor; objectName: "consoleHostEditor"; Layout.fillWidth: true; placeholderText: "server.home.arpa or 192.168.1.10"; text: String(page.controller.setting("consoleHost", "")); foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: page.controller.persistKeepingOpen({consoleHost: text.trim()}) }
            Button { text: "Save"; onClicked: page.controller.persistKeepingOpen({consoleHost: consoleHostEditor.text.trim()}) }
          }
          }

          P2PSectionHeading { title: "Service filtering"; description: "Optionally limit discovery to selected backend IDs." }
          SettingsSurface {
          RowLayout {
            Layout.fillWidth: true
            TextField { id: serviceAllowlistEditor; objectName: "serviceAllowlistEditor"; Layout.fillWidth: true; placeholderText: "yggdrasil, i2pd, syncthing"; text: Model.enabled(page.controller.setting("enabledServices", []), []).join(", "); foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family }
            Button { objectName: "serviceAllowlistSaveButton"; text: "Save"; onClicked: { var ids = serviceAllowlistEditor.text.split(",").map(function(value) { return value.trim() }).filter(function(value) { return value !== "" }); page.controller.persistKeepingOpen({enabledServices: ids}) } }
          }
          }

          P2PSectionHeading { id: customHeading; title: "Custom services"; description: "Add validated, observation-only process or systemd services." }
          SettingsSurface {
          Text { Layout.fillWidth: true; text: "JSON array; IDs begin custom-. Executable, process, and unit fields support detection but never control actions."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
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
            animationEnabled: page.controller.settingsPage === "discovery"
            label: page.controller.settingsTransferLabel()
            style: String(page.controller.setting("loadingIndicatorStyle", "spinner"))
            glyph: String(page.controller.setting("loadingIndicatorGlyph", ">"))
            speed: Number(page.controller.setting("loadingIndicatorSpeed", 140)) || 140
            tone: page.controller.themeColor("accent", Color.accent)
          }
          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "settingsExportButton"; text: "Export settings"; enabled: !page.controller.settingsTransferRunning && !page.controller.settingsPersistenceRunning; onClicked: page.controller.exportSettings() }
            Button { objectName: "settingsImportButton"; text: "Import settings"; enabled: !page.controller.settingsTransferRunning && !page.controller.settingsPersistenceRunning; tooltipText: "Import the previously exported settings file"; onClicked: page.controller.importSettings() }
            Button { objectName: "settingsUndoButton"; text: "Undo last change"; enabled: !page.controller.settingsTransferRunning && !page.controller.settingsPersistenceRunning && page.controller.settingsUndoAvailable; tooltipText: enabled ? "Restore the previous durable settings snapshot" : "No previous durable settings snapshot is available"; onClicked: page.controller.undoSettings() }
            Item { Layout.fillWidth: true }
          }
          }
}
