import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "general"
  Layout.fillWidth: true
  spacing: Style.spacing.md
  function sectionY(section) { return section === "notifications" ? notificationsHeading.y : section === "behavior" ? behaviorHeading.y : -1 }
          P2PSectionHeading { id: behaviorHeading; visible: page.controller.settingsPage === "general"; title: "Startup and behavior"; description: "Choose what the widget shows first and how common actions behave." }
          SettingsSurface {
          visible: page.controller.settingsPage === "general"
          P2PSettingsGrid {
          objectName: "behaviorToggleGrid"
          Toggle { objectName: "privacyFilterToggle"; Layout.fillWidth: true; label: "Privacy filter"; description: "Redact endpoints, process IDs, paths, and console URLs before they reach the widget."; checked: page.controller.privacyFilter; foreground: Color.popups.text; accent: checked ? Color.bar.active : Color.urgent; fontFamily: Style.font.family; onClicked: page.controller.togglePrivacyFilter() }
          Toggle { objectName: "showStoppedToggle"; Layout.fillWidth: true; label: "Show stopped services"; checked: page.controller.showStopped; foreground: Color.popups.text; accent: Color.bar.active; fontFamily: Style.font.family; onClicked: page.controller.persistKeepingOpen({showStopped: !checked}) }
          P2PSettingToggle { controller: page.controller; settingKey: "showCount"; label: "Show active count in bar"; fallback: true }
          P2PSettingToggle { objectName: "autoStartAfterInstallToggle"; controller: page.controller; settingKey: "autoStartAfterInstall"; label: "Start after install"; tooltipText: "Start services after install"; fallback: false; description: "Start and verify every package-managed service immediately after Omarchy installs it." }
          P2PSettingToggle { objectName: "actionNotificationsToggle"; controller: page.controller; settingKey: "notifyOnControlChanges"; label: "Action notifications"; tooltipText: "Service action notifications"; fallback: true; description: "Notify when start, stop, or restart succeeds, is cancelled, or fails." }
          P2PSettingToggle { controller: page.controller; settingKey: "showTrafficStats"; label: "Live transfer speeds"; fallback: true; description: "Show aggregate container receive and transmit rates while traffic is active." }
          }
          P2PSettingsGrid {
          objectName: "defaultViewGrid"
          Dropdown { objectName: "defaultViewDropdown"; Layout.fillWidth: true; label: "Default panel view"; value: String(page.controller.setting("defaultView","all")); options: [{value:"all",label:"All services"},{value:"running",label:"Running"},{value:"stopped",label:"Stopped"},{value:"issues",label:"Issues"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({defaultView:next}) } }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.xs
            Text { text: "Default saved view"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            RowLayout {
              Layout.fillWidth: true
              TextField {
                id: defaultSavedViewEditor
                objectName: "defaultSavedViewEditor"
                Layout.fillWidth: true
                placeholderText: "Saved view name"
                text: String(page.controller.setting("defaultSavedView", ""))
                foreground: Color.popups.text
                accent: Color.bar.active
                font.family: Style.font.family
                onAccepted: page.controller.persistKeepingOpen({defaultSavedView: text.trim()})
              }
              Button { text: "Save"; onClicked: page.controller.persistKeepingOpen({defaultSavedView: defaultSavedViewEditor.text.trim()}) }
            }
          }
          }
          }

          P2PSectionHeading { id: notificationsHeading; visible: page.controller.settingsPage === "general"; title: "Notifications"; description: "Choose which requested actions and automatic state changes should notify you." }
          SettingsSurface {
          visible: page.controller.settingsPage === "general"
          P2PSettingsGrid {
          objectName: "notificationToggleGrid"
          P2PSettingToggle { controller: page.controller; settingKey: "notifyUnexpectedStops"; label: "Unexpected stops"; fallback: false }
          P2PSettingToggle { controller: page.controller; settingKey: "notifyRecovery"; label: "Service recovery"; fallback: false }
          P2PSettingToggle { controller: page.controller; settingKey: "notifyUnhealthy"; label: "Unhealthy services"; fallback: true }
          P2PSettingToggle { controller: page.controller; settingKey: "notifyRestartEvents"; label: "Restart threshold"; fallback: true }
          }
          P2PSettingsGrid {
            objectName: "notificationValueGrid"
            IntegerSetting { controller: page.controller; settingKey: "notificationCooldownSeconds"; label: "Notification cooldown, seconds"; minimum: 0; maximum: 300; fallback: 30 }
            IntegerSetting { controller: page.controller; settingKey: "restartWarningThreshold"; label: "Restart warning threshold"; minimum: 1; maximum: 100; fallback: 3 }
            P2PSettingToggle { controller: page.controller; settingKey: "enableEventJournal"; label: "Local event journal"; fallback: false; description: "Keep a bounded, privacy-filtered history of service changes and action outcomes." }
            IntegerSetting { controller: page.controller; settingKey: "eventJournalLimit"; label: "Visible journal entries"; minimum: 5; maximum: 100; fallback: 25 }
          }
          }
}
