import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "general"
    property bool showingWidgetSettings: true
    property var bar: null
    property var selections: []
    property string settingsSaveStatus: "saving"
    function setting(_key, fallback) { return fallback }
    function settingsPageDescription() { return "GENERAL" }
    function showSettingsPage(page) {
      selections = selections.concat([page])
      settingsPage = page
    }
  }

  P2PSettingsNavigation { id: navigation; controller: mockController }

  function descendant(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    var children = item.children || []
    for (var index = 0; index < children.length; index++) {
      var match = descendant(children[index], name)
      if (match) return match
    }
    return null
  }

  Component.onCompleted: Qt.callLater(function() {
    var services = descendant(navigation, "settingsPageButton-services")
    var back = descendant(navigation, "settingsBackButton")
    var saving = descendant(navigation, "settingsSaveLoadingIndicator")
    var saved = descendant(navigation, "settingsSavedStatus")
    if (!services || !back || !saving || !saved) throw new Error("settings navigation controls are not addressable")
    if (!saving.visible || saved.visible) throw new Error("settings saving presentation failed")
    mockController.settingsSaveStatus = "saved"
    if (saving.visible || !saved.visible) throw new Error("settings saved presentation failed")
    services.clicked()
    if (mockController.selections.length !== 1 || mockController.selections[0] !== "services" || mockController.settingsPage !== "services")
      throw new Error("settings page selection failed")
    if (!services.active || !services.selected) throw new Error("selected settings page was not reflected")
    back.clicked()
    if (mockController.showingWidgetSettings) throw new Error("settings back action failed")
    console.log("P2P_QML_SETTINGS_NAVIGATION_OK")
    Qt.quit()
  })
}
