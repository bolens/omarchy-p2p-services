import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "services"
  Layout.fillWidth: true
  spacing: Style.spacing.md
  function sectionY(_section) { return -1 }
          P2PSectionHeading { visible: page.controller.settingsPage === "services"; title: "Ordering and grouping"; description: "Choose how services are ranked, pinned, grouped, and stabilized." }
          SettingsSurface {
          visible: page.controller.settingsPage === "services"
          P2PSettingToggle { controller: page.controller; settingKey: "persistCollapsedGroups"; label: "Remember collapsed groups"; fallback: true }
          Dropdown {
            objectName: "serviceSortModeDropdown"
            Layout.fillWidth: true
            label: "Service sorting"
            value: String(page.controller.setting("serviceSortMode", "custom"))
            options: [{value:"custom",label:"Custom order"},{value:"name",label:"Name"},{value:"category",label:"Category"},{value:"status",label:"Status"},{value:"activity",label:"Live activity"},{value:"connections",label:"Connections"},{value:"uptime",label:"Uptime"},{value:"traffic",label:"Transfer rate"},{value:"backend",label:"Backend"},{value:"recent",label:"Recently changed"},{value:"errors",label:"Error severity"}]
            foreground: Color.popups.text
            accent: Color.bar.active
            onChanged: function(next) { page.controller.persistKeepingOpen({serviceSortMode: next}) }
          }
          Dropdown {
            objectName: "serviceSortDirectionDropdown"
            Layout.fillWidth: true
            label: "Sort direction"
            value: String(page.controller.setting("serviceSortDirection", "automatic"))
            options: [{value:"automatic",label:"Automatic"},{value:"ascending",label:"Ascending"},{value:"descending",label:"Descending"}]
            foreground: Color.popups.text
            accent: Color.bar.active
            onChanged: function(next) { page.controller.persistKeepingOpen({serviceSortDirection: next}) }
          }
          P2PSettingToggle { controller: page.controller; settingKey: "favoritesFirst"; label: "Favorites first"; fallback: true; description: "Keep favorite services pinned above the selected sort order." }
          P2PSettingToggle { controller: page.controller; settingKey: "runningFirst"; label: "Running services first"; fallback: false; description: "Keep running services above stopped services independently of sorting." }
          P2PSettingToggle { controller: page.controller; settingKey: "stableLiveSort"; label: "Stabilize live sorting"; fallback: true; description: "Hold card positions briefly after refreshes and during scrolling or actions." }
          Dropdown {
            objectName: "serviceGroupModeDropdown"
            Layout.fillWidth: true
            label: "Group services"
            value: String(page.controller.setting("serviceGroupMode", "none"))
            options: [{value:"none",label:"No grouping"},{value:"status",label:"Status"},{value:"category",label:"Category"},{value:"backend",label:"Backend"},{value:"scope",label:"Control scope"},{value:"favorite",label:"Favorites"}]
            foreground: Color.popups.text; accent: Color.bar.active
            onChanged: function(next) { page.controller.persistKeepingOpen({serviceGroupMode: next}) }
          }
          Dropdown {
            objectName: "serviceGroupDirectionDropdown"
            visible: page.controller.setting("serviceGroupMode", "none") !== "none"
            Layout.fillWidth: true
            label: "Group order"
            value: String(page.controller.setting("serviceGroupDirection", "automatic"))
            options: [{value:"automatic",label:"Smart order"},{value:"ascending",label:"A to Z"},{value:"descending",label:"Z to A"}]
            foreground: Color.popups.text; accent: Color.bar.active
            onChanged: function(next) { page.controller.persistKeepingOpen({serviceGroupDirection: next}) }
          }
          P2PSettingToggle { visible: page.controller.setting("serviceGroupMode", "none") !== "none"; controller: page.controller; settingKey: "showGroupIcons"; label: "Group icons"; fallback: true }
          P2PSettingToggle { visible: page.controller.setting("serviceGroupMode", "none") !== "none"; controller: page.controller; settingKey: "showGroupCounts"; label: "Group counts"; fallback: true }
          Dropdown {
            objectName: "groupCountModeDropdown"
            visible: page.controller.setting("serviceGroupMode", "none") !== "none" && page.controller.setting("showGroupCounts", true) === true
            Layout.fillWidth: true
            label: "Group count format"
            value: String(page.controller.setting("groupCountMode", "active-total"))
            options: [{value:"active-total",label:"Active / total"},{value:"active",label:"Active only"},{value:"total",label:"Total only"}]
            foreground: Color.popups.text; accent: Color.bar.active
            onChanged: function(next) { page.controller.persistKeepingOpen({groupCountMode: next}) }
          }
          Text { visible: page.controller.setting("serviceSortMode", "custom") === "traffic" && page.controller.setting("showTrafficStats", true) !== true; Layout.fillWidth: true; text: "Transfer-rate sorting needs Live transfer speeds enabled."; textFormat: Text.PlainText; color: Color.urgent; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }

          P2PSectionHeading { visible: page.controller.settingsPage === "services"; title: "Saved views"; description: "Store and reuse a filter, search, sort, and grouping combination." }
          SettingsSurface {
          visible: page.controller.settingsPage === "services"
          RowLayout {
            Layout.fillWidth: true
            TextField { id: savedViewName; Layout.fillWidth: true; placeholderText: "Saved view name"; foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: { page.controller.saveCurrentView(text); text = "" } }
            Button { text: "Save current view"; onClicked: { page.controller.saveCurrentView(savedViewName.text); savedViewName.text = "" } }
          }
          Repeater {
            model: page.controller.setting("savedViews", []) || []
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Text { Layout.fillWidth: true; text: modelData.name + " · " + modelData.filter + " · " + modelData.sortMode + (modelData.groupMode && modelData.groupMode !== "none" ? " · " + modelData.groupMode + " groups" : ""); textFormat: Text.PlainText; color: Color.muted; elide: Text.ElideRight; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Button { text: "Apply"; onClicked: page.controller.applyView(modelData) }
              Button { text: "Remove"; onClicked: page.controller.removeSavedView(modelData.name) }
            }
          }
          }
}
