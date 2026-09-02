pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property var values: ({runningColorRole:"unsupported"})
    property var patches: []
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) { patches = patches.concat([patch]); values = Object.assign({}, values, patch) }
  }

  P2PThemeRoleSetting {
    id: roleSetting
    controller: mockController
    settingKey: "runningColorRole"
    label: "Running color"
    fallback: "accent"
  }

  Component.onCompleted: Qt.callLater(function() {
    if (roleSetting.value !== "accent") throw new Error("unsupported stored theme role was not normalized")
    roleSetting.changed("urgent")
    if (mockController.patches.length !== 1 || mockController.patches[0].runningColorRole !== "urgent")
      throw new Error("valid theme role was not persisted")
    roleSetting.changed("invalid-role")
    if (mockController.patches.length !== 1) throw new Error("unsupported theme role was persisted")
    mockController.values = ({runningColorRole:"muted"})
    Qt.callLater(function() {
      if (roleSetting.value !== "muted") throw new Error("externally reloaded theme role was ignored")
      console.log("P2P_QML_THEME_ROLE_SETTING_OK")
      Qt.quit()
    })
  })
}
