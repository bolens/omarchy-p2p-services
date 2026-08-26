import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "general"
    property bool privacyFilter: true
    property bool showStopped: false
    property int privacyToggles: 0
    property var patches: []
    function setting(key, fallback) {
      var values = {defaultView:"all",defaultSavedView:"Morning",notificationCooldownSeconds:30,restartWarningThreshold:3}
      return values[key] === undefined ? fallback : values[key]
    }
    function persistKeepingOpen(patch) { patches = patches.concat([patch]) }
    function togglePrivacyFilter() { privacyToggles += 1; privacyFilter = !privacyFilter }
  }

  P2PGeneralSettings { id: page; width: 600; controller: mockController }

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
    var privacy = descendant(page, "privacyFilterToggle")
    var stopped = descendant(page, "showStoppedToggle")
    var defaultView = descendant(page, "defaultViewDropdown")
    var savedView = descendant(page, "defaultSavedViewEditor")
    var behaviorGrid = descendant(page, "behaviorToggleGrid")
    var notificationGrid = descendant(page, "notificationToggleGrid")
    var defaultGrid = descendant(page, "defaultViewGrid")
    if (!privacy || !stopped || !defaultView || !savedView || !behaviorGrid || !notificationGrid || !defaultGrid) throw new Error("general settings controls are not addressable")
    if (!behaviorGrid.twoColumns || !notificationGrid.twoColumns || !defaultGrid.twoColumns) throw new Error("wide general settings did not use paired fields")
    privacy.clicked(); stopped.clicked(); defaultView.changed("issues")
    savedView.text = "  Evening  "; savedView.accepted()
    if (mockController.privacyToggles !== 1 || mockController.privacyFilter !== false) throw new Error("privacy toggle dispatch failed")
    if (mockController.patches.length !== 3) throw new Error("general settings event count failed")
    if (mockController.patches[0].showStopped !== true) throw new Error("show-stopped toggle failed")
    if (mockController.patches[1].defaultView !== "issues") throw new Error("default view selection failed")
    if (mockController.patches[2].defaultSavedView !== "Evening") throw new Error("default saved-view normalization failed")
    console.log("P2P_QML_GENERAL_SETTINGS_OK")
    Qt.quit()
  })
}
