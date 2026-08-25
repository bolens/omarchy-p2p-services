import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property var privacyFilterOverride: false
    property var savedPatch: null
    property var values: ({
      serviceLabels:{syncthing:"Home Sync"},serviceIcons:{syncthing:"S"},
      serviceShowStopped:{syncthing:false},serviceConsoleUrls:{syncthing:"https://sync.example.test"},
      serviceNotificationPolicies:{syncthing:"silent"},favoriteServices:["syncthing"],serviceOrder:["syncthing"]
    })
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) { savedPatch = patch }
  }

  P2PSettingsReset { id: reset; controller: mockController }

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
    var button = descendant(reset, "settingsResetButton")
    if (!button) throw new Error("settings reset button is not addressable")
    button.clicked()
    var patch = mockController.savedPatch
    if (!patch || mockController.privacyFilterOverride !== undefined) throw new Error("settings reset dispatch failed")
    if (patch.popupWidth !== 600 || patch.serviceSortMode !== "custom") throw new Error("global defaults were not restored")
    if (patch.serviceLabels.syncthing !== "Home Sync" || patch.serviceIcons.syncthing !== "S" || patch.serviceShowStopped.syncthing !== false)
      throw new Error("service display customizations were not preserved")
    if (patch.serviceConsoleUrls.syncthing !== "https://sync.example.test" || patch.serviceNotificationPolicies.syncthing !== "silent")
      throw new Error("service action customizations were not preserved")
    if (patch.favoriteServices[0] !== "syncthing" || patch.serviceOrder[0] !== "syncthing") throw new Error("service organization was not preserved")
    console.log("P2P_QML_SETTINGS_RESET_OK")
    Qt.quit()
  })
}
