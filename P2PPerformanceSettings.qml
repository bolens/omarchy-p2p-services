import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "performance"
  Layout.fillWidth: true
  spacing: Style.spacing.md
  function sectionY(section) { return section === "diagnostics" ? diagnosticsHeading.y : section === "refresh" ? refreshHeading.y : -1 }
          P2PSectionHeading { title: "Performance"; description: "Balance visible freshness against background process and container-runtime queries." }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: healthColumn.implicitHeight + Style.spacing.md * 2
            radius: Style.cornerRadius
            color: Util.alpha(page.controller.consecutiveRefreshFailures ? Color.urgent : Color.accent, 0.07)
            border.width: 1
            border.color: Util.alpha(page.controller.consecutiveRefreshFailures ? Color.urgent : Color.accent, 0.2)
            ColumnLayout {
              id: healthColumn
              anchors.fill: parent
              anchors.margins: Style.spacing.md
              Text { text: page.controller.consecutiveRefreshFailures ? "Refresh degraded" : "Refresh healthy"; textFormat: Text.PlainText; color: page.controller.consecutiveRefreshFailures ? Color.urgent : Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body; font.weight: Font.DemiBold }
          Text { Layout.fillWidth: true; text: page.controller.refreshHealthText(); textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }
          P2PSectionHeading { id: refreshHeading; title: "Refresh cadence"; description: "Set periodic polling and full reconciliation intervals." }
          SettingsSurface {
          P2PSettingsGrid {
            id: refreshCadenceGrid
            IntegerSetting { controller: page.controller; settingKey: "refreshSeconds"; label: "Open-panel refresh interval, seconds"; minimum: 2; maximum: 60; fallback: 5 }
            IntegerSetting { controller: page.controller; settingKey: "backgroundRefreshSeconds"; label: "Background refresh interval, seconds"; minimum: 15; maximum: 300; fallback: 15 }
            IntegerSetting { Layout.columnSpan: refreshCadenceGrid.twoColumns ? 2 : 1; controller: page.controller; settingKey: "reconcileSeconds"; label: "Full container reconciliation, seconds"; minimum: 30; maximum: 600; fallback: 60; description: "Full scans include stopped containers; normal refreshes inspect running containers only." }
          }
          }
          P2PSectionHeading { title: "Refresh triggers"; description: "Control event-driven and immediate refresh behavior." }
          SettingsSurface {
          P2PSettingsGrid {
          id: refreshTriggerGrid
          objectName: "refreshTriggerGrid"
          P2PSettingToggle { controller: page.controller; settingKey: "eventRefresh"; label: "Event-assisted refresh"; fallback: true; description: "React to systemd and container events while retaining periodic polling as a fallback." }
          P2PSettingToggle { controller: page.controller; settingKey: "refreshOnOpen"; label: "Refresh when opened"; fallback: true }
          P2PSettingToggle { controller: page.controller; settingKey: "refreshAfterSettings"; label: "Refresh after settings changes"; fallback: true }
          P2PSettingToggle { controller: page.controller; settingKey: "refreshAfterActions"; label: "Refresh after service actions"; fallback: true }
          IntegerSetting { Layout.columnSpan: refreshTriggerGrid.twoColumns ? 2 : 1; controller: page.controller; settingKey: "staleWarningSeconds"; label: "Stale warning threshold, seconds"; minimum: 15; maximum: 600; fallback: 60 }
          }
          }
          P2PSectionHeading { title: "Traffic sampling"; description: "Smooth container counters and ignore insignificant transfer activity." }
          SettingsSurface {
          P2PSettingsGrid {
            IntegerSetting { controller: page.controller; settingKey: "trafficSmoothingSeconds"; label: "Traffic smoothing window, seconds"; minimum: 1; maximum: 30; fallback: 3 }
            IntegerSetting { controller: page.controller; settingKey: "trafficMinimumBytesPerSecond"; label: "Minimum visible traffic, B/s"; minimum: 0; maximum: 10485760; fallback: 1024 }
          }
          }
          P2PSectionHeading { id: diagnosticsHeading; title: "Monitor diagnostics"; description: "Live health from the shared background watcher." }
          SettingsSurface {
          Text { Layout.fillWidth: true; text: page.controller.monitoringTelemetryText(); textFormat: Text.PlainText; color: page.controller.p2pService && Model.monitoringHealthSeverity(page.controller.p2pService.watcherHealth, page.controller.p2pService.settingsWatcherHealth, page.controller.p2pService.settingsWatcherCode) === "neutral" ? Color.muted : Color.urgent; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "copySupportReportButton"; text: "Copy support report"; tooltipText: "Copy a whole-plugin report with privacy filtering forced on"; onClicked: page.controller.copySupportReport() }
            Button { visible: page.controller.setting("enableEventJournal", false) === true; text: "Clear event journal"; onClicked: page.controller.clearEventJournal() }
            Item { Layout.fillWidth: true }
          }
          ColumnLayout {
            visible: page.controller.setting("enableEventJournal", false) === true
            Layout.fillWidth: true
            Repeater {
              model: Model.eventJournalRows(page.controller.eventJournal, page.controller.setting("eventJournalLimit", 25))
              Text { required property var modelData; Layout.fillWidth: true; text: new Date(modelData.at * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat) + "  ·  " + modelData.kind.replace(/-/g, " ") + (modelData.count > 1 ? " ×" + modelData.count : ""); textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Text { visible: page.controller.eventJournal.length === 0; text: "No recorded events."; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
          }
}
