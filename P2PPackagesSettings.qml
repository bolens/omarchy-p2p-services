import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "packages"
  Layout.fillWidth: true
  spacing: Style.spacing.md
  P2PLoadingIndicator {
    objectName: "catalogLoadingIndicator"
    running: page.controller.setting("showLoadingIndicators", true) === true && page.controller.catalogLoading
    label: "QUERYING PACKAGE CATALOG"
    style: String(page.controller.setting("loadingIndicatorStyle", "spinner"))
    glyph: String(page.controller.setting("loadingIndicatorGlyph", ">"))
    speed: Number(page.controller.setting("loadingIndicatorSpeed", 140)) || 140
    tone: page.controller.themeColor("accent", Color.accent)
  }
          P2PSectionHeading { title: "Service packages"; description: "Install supported clients or remove package-managed services." }
          SettingsSurface {
            IntegerSetting { controller: page.controller; settingKey: "backupRetention"; label: "Configuration backups retained per service"; minimum: 1; maximum: 50; fallback: 10 }
          }
          RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Available to install · " + page.controller.missingServices.length; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
            Button { objectName: "availablePackagesToggle"; text: page.controller.availablePackagesExpanded ? "Show less" : "Show all"; visible: page.controller.missingServices.length > 5; onClicked: page.controller.availablePackagesExpanded = !page.controller.availablePackagesExpanded }
          }
          Repeater {
            model: page.controller.settingsPage === "packages" ? page.controller.visibleMissingServices : []
            delegate: Rectangle {
              id: availablePackageCard
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: availablePackageRow.implicitHeight + Style.spacing.sm * 2
              radius: Style.cornerRadius
              color: Util.alpha(Color.accent, 0.035)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.12)
              RowLayout {
                id: availablePackageRow
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                Text { text: availablePackageCard.modelData.icon; textFormat: Text.PlainText; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { Layout.fillWidth: true; text: availablePackageCard.modelData.name; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.weight: Font.DemiBold }
                  Text { Layout.fillWidth: true; text: availablePackageCard.modelData.packages.join(" / "); textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
                Button { objectName: "installPackageButton-" + availablePackageCard.modelData.id; text: "Install"; onClicked: page.controller.installService(availablePackageCard.modelData) }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Installed services · " + page.controller.detectedServiceCatalog.length; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold }
            Button { objectName: "installedPackagesToggle"; text: page.controller.installedPackagesExpanded ? "Show less" : "Show all"; visible: page.controller.detectedServiceCatalog.length > 5; onClicked: page.controller.installedPackagesExpanded = !page.controller.installedPackagesExpanded }
          }
          Text { Layout.fillWidth: true; text: "Package-managed services can be removed after they are stopped. Configuration is backed up first. Container and manual installs remain externally managed."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Repeater {
            model: page.controller.settingsPage === "packages" ? page.controller.visibleDetectedServiceCatalog : []
            delegate: Rectangle {
              id: installedPackageCard
              required property var modelData
              readonly property var runtime: page.controller.service(modelData.id)
              readonly property bool removable: modelData.installedPackages && modelData.installedPackages.length > 0
              Layout.fillWidth: true
              implicitHeight: installedPackageRow.implicitHeight + Style.spacing.sm * 2
              radius: Style.cornerRadius
              color: Util.alpha(Color.muted, 0.025)
              border.width: 1
              border.color: Util.alpha(Color.muted, 0.12)
              RowLayout {
                id: installedPackageRow
                anchors.fill: parent
                anchors.margins: Style.spacing.sm
                Text { text: installedPackageCard.modelData.icon; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text { Layout.fillWidth: true; text: installedPackageCard.modelData.name; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.weight: Font.DemiBold }
                  Text { Layout.fillWidth: true; text: installedPackageCard.removable ? installedPackageCard.modelData.installedPackages.join(" / ") : "Externally managed"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
                Button { objectName: "stopPackageButton-" + installedPackageCard.modelData.id; text: "Stop"; visible: installedPackageCard.removable && installedPackageCard.runtime && installedPackageCard.runtime.active; enabled: page.controller.pendingService === ""; onClicked: page.controller.act(installedPackageCard.runtime, "stop") }
                Button {
                  objectName: "uninstallPackageButton-" + installedPackageCard.modelData.id
                  text: "Uninstall"
                  visible: installedPackageCard.removable
                  enabled: installedPackageCard.runtime && !installedPackageCard.runtime.active && page.controller.pendingService === ""
                  tooltipText: enabled ? "Uninstall package and preserve a private config backup" : "Stop the service before uninstalling"
                  onClicked: page.controller.requestUninstall(installedPackageCard.runtime)
                }
              }
            }
          }
}
