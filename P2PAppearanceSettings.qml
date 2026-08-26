import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id: page
  required property var controller
  visible: controller.settingsPage === "appearance"
  Layout.fillWidth: true
  spacing: Style.spacing.md
  function sectionY(_section) { return -1 }
  function saveWidgetIcon(value) {
    var icon = String(value || "").trim()
    page.controller.persistKeepingOpen({widgetIcon: icon || "󰒍"})
  }
          P2PSectionHeading { visible: page.controller.settingsPage === "appearance"; title: "Service cards"; description: "Choose the main view layout and how much each card reveals." }
          SettingsSurface {
          visible: page.controller.settingsPage === "appearance"
          P2PSettingsGrid {
            Dropdown { objectName: "serviceLayoutDropdown"; Layout.fillWidth: true; label: "Layout"; value: String(page.controller.setting("serviceLayout", "list")); options: [{value:"list",label:"Single-column list"},{value:"grid",label:"Two-column grid"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({serviceLayout:next}) } }
            Dropdown { objectName: "cardDensityDropdown"; Layout.fillWidth: true; label: "Card density"; value: String(page.controller.setting("cardDensity","comfortable")); options: [{value:"comfortable",label:"Comfortable"},{value:"compact",label:"Compact"},{value:"minimal",label:"Minimal"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({cardDensity:next}) } }
          }
          Text { Layout.fillWidth: true; text: page.controller.setting("cardDensity", "comfortable") === "comfortable" ? "Status, glanceable metrics, and actions." : (page.controller.setting("cardDensity", "comfortable") === "compact" ? "Condensed metrics with icon actions." : "Identity and status only."); textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          P2PSettingsGrid {
            P2PSettingToggle { controller: page.controller; settingKey: "showStatusRail"; label: "Status rail"; fallback: true }
            P2PSettingToggle { controller: page.controller; settingKey: "showFavoriteMarker"; label: "Favorite marker"; fallback: true }
            P2PSettingToggle { controller: page.controller; settingKey: "showBackendBadge"; label: "Backend badge"; fallback: false }
            P2PSettingToggle { controller: page.controller; settingKey: "showCardSummary"; label: "Card summary"; fallback: true }
            P2PSettingToggle { controller: page.controller; settingKey: "showQuickActions"; label: "Quick actions"; fallback: true }
            P2PSettingToggle { controller: page.controller; settingKey: "compactHeader"; label: "Compact header"; fallback: false; description: "Use a text summary instead of status chips." }
          }
          Dropdown { objectName: "groupHeaderStyleDropdown"; Layout.fillWidth: true; label: "Group header style"; value: String(page.controller.setting("groupHeaderStyle","surfaced")); options: [{value:"surfaced",label:"Surfaced"},{value:"dense",label:"Dense"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({groupHeaderStyle:next}) } }
          }
          P2PSectionHeading { visible: page.controller.settingsPage === "appearance"; title: "Bar and panel"; description: "Tune the compact bar indicator and popup dimensions." }
          SettingsSurface {
          visible: page.controller.settingsPage === "appearance"
          Text { text: "Bar icon"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          RowLayout {
            Layout.fillWidth: true
            TextField { id: widgetIconEditor; objectName: "widgetIconEditor"; Layout.fillWidth: true; text: String(page.controller.setting("widgetIcon", "󰒍")); placeholderText: "󰒍"; foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: page.saveWidgetIcon(text) }
            Button { text: "Save"; onClicked: page.saveWidgetIcon(widgetIconEditor.text) }
          }

          P2PSettingsGrid {
            IntegerSetting { controller: page.controller; settingKey: "popupMaxHeight"; label: "Popup maximum height"; minimum: 360; maximum: 900; fallback: 600 }
            IntegerSetting { controller: page.controller; settingKey: "popupWidth"; label: "Popup width"; minimum: 420; maximum: 800; fallback: 600 }
          }
          Dropdown { objectName: "barPresentationDropdown"; Layout.fillWidth: true; label: "Bar presentation"; value: String(page.controller.setting("barPresentation","active")); options: [{value:"icon",label:"Icon only"},{value:"active",label:"Active count"},{value:"active-total",label:"Active / total"},{value:"health",label:"Health indicator"},{value:"category-active",label:"Category active counts"},{value:"category-active-total",label:"Category active / total"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({barPresentation:next}) } }
          P2PSettingToggle { controller: page.controller; settingKey: "hideZeroCount"; label: "Hide zero count"; fallback: false; description: "Show only the icon when no services are active." }
          ColumnLayout {
            Layout.fillWidth: true
            visible: String(page.controller.setting("barPresentation", "active")).indexOf("category-") === 0
            spacing: Style.spacing.xs
            Text { text: "Category icons"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Repeater {
              model: page.controller.categorySummaries()
              delegate: RowLayout {
                id: categoryIconRow
                required property var modelData
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: categoryIconRow.modelData.category; textFormat: Text.PlainText; color: Color.popups.text; font.family: Style.font.family; font.pixelSize: Style.font.body }
                TextField { id: categoryIconEditor; objectName: "categoryIconEditor"; Layout.preferredWidth: Style.space(72); text: categoryIconRow.modelData.icon; foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: page.controller.saveCategoryIcon(categoryIconRow.modelData.category, text) }
                Button { text: "Save"; onClicked: page.controller.saveCategoryIcon(categoryIconRow.modelData.category, categoryIconEditor.text) }
              }
            }
          }
          P2PSettingsGrid {
            IntegerSetting { controller: page.controller; settingKey: "barFontSize"; label: "Bar font size"; minimum: 8; maximum: 28; fallback: 14 }
            IntegerSetting { controller: page.controller; settingKey: "barHorizontalMargin"; label: "Horizontal margin"; minimum: 0; maximum: 24; fallback: 8 }
            IntegerSetting { controller: page.controller; settingKey: "barVerticalPadding"; label: "Vertical padding"; minimum: 0; maximum: 16; fallback: 6 }
            IntegerSetting { controller: page.controller; settingKey: "barFixedWidth"; label: "Fixed width (0 = automatic)"; minimum: 0; maximum: 240; fallback: 0 }
          }
          Dropdown { objectName: "barTextRotationDropdown"; Layout.fillWidth: true; label: "Text rotation"; value: String(page.controller.setting("barTextRotation", "normal")); options: [{value:"normal",label:"Normal"},{value:"clockwise",label:"Clockwise"},{value:"counterclockwise",label:"Counterclockwise"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({barTextRotation:next}) } }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "barForegroundColorRole"; label: "Idle color"; fallback: "foreground" }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "barActiveColorRole"; label: "Active color"; fallback: "accent" }
          P2PSettingToggle { controller: page.controller; settingKey: "barDimWhenIdle"; label: "Dim while idle"; fallback: false; description: "Reduce opacity when no services are active and the panel is closed." }
          }

          P2PSectionHeading { visible: page.controller.settingsPage === "appearance"; title: "Loading indicators"; description: "Choose how unfinished service, catalog, and settings content is represented." }
          SettingsSurface {
          visible: page.controller.settingsPage === "appearance"
          P2PSettingToggle { controller: page.controller; settingKey: "showLoadingIndicators"; label: "Show loading indicators"; fallback: true; description: "Use compact terminal-style placeholders instead of presenting unfinished content as empty." }
          Dropdown { objectName: "loadingIndicatorStyleDropdown"; Layout.fillWidth: true; label: "Indicator style"; value: String(page.controller.setting("loadingIndicatorStyle", "spinner")); options: [{value:"spinner",label:"Braille spinner"},{value:"dots",label:"Terminal dots"},{value:"bar",label:"Progress sweep"},{value:"glyph",label:"Custom glyph"}]; foreground: Color.popups.text; accent: Color.bar.active; onChanged: function(next) { page.controller.persistKeepingOpen({loadingIndicatorStyle:next}) } }
          TextField { objectName: "loadingIndicatorGlyphEditor"; Layout.fillWidth: true; visible: String(page.controller.setting("loadingIndicatorStyle", "spinner")) === "glyph"; text: String(page.controller.setting("loadingIndicatorGlyph", ">")); placeholderText: ">"; foreground: Color.popups.text; accent: Color.bar.active; font.family: Style.font.family; onAccepted: page.controller.persistKeepingOpen({loadingIndicatorGlyph:String(text || ">").slice(0, 4)}) }
          IntegerSetting { controller: page.controller; settingKey: "loadingIndicatorSpeed"; label: "Animation interval, ms"; minimum: 60; maximum: 1000; fallback: 140 }
          }

          P2PSectionHeading { visible: page.controller.settingsPage === "appearance"; title: "Theme roles"; description: "Map service states and activity to colors from the active Omarchy theme." }
          SettingsSurface {
          visible: page.controller.settingsPage === "appearance"
          P2PThemeRoleSetting { controller: page.controller; settingKey: "runningColorRole"; label: "Running color"; fallback: "accent" }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "stoppedColorRole"; label: "Stopped color"; fallback: "muted" }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "errorColorRole"; label: "Error color"; fallback: "urgent" }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "favoriteColorRole"; label: "Favorite color"; fallback: "accent" }
          P2PThemeRoleSetting { controller: page.controller; settingKey: "activityColorRole"; label: "Transfer activity color"; fallback: "accent" }
          }
}
