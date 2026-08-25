import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: panel
  required property var controller
  Layout.fillWidth: true
  spacing: Style.spacing.md

  P2PSettingsNavigation { controller: panel.controller }
  P2PGeneralSettings { controller: panel.controller }
  P2PAppearanceSettings { controller: panel.controller }
  P2PServicesSettings { controller: panel.controller }
  P2PPerformanceSettings { controller: panel.controller }
  P2PDiscoverySettings { controller: panel.controller }
  P2PPackagesSettings { controller: panel.controller }

  PanelSeparator { Layout.fillWidth: true; foreground: panel.controller.bar ? panel.controller.bar.foreground : Color.popups.text }
  P2PSettingsReset { controller: panel.controller }
}
