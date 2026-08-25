import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property var values: ({enabled:false,interval:5})
    property var patches: []
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) {
      patches = patches.concat([patch])
      values = Object.assign({}, values, patch)
    }
  }

  P2PSettingToggle {
    id: settingToggle
    controller: mockController
    settingKey: "enabled"
    fallback: true
  }

  IntegerSetting {
    id: integerSetting
    controller: mockController
    settingKey: "interval"
    label: "Interval"
    minimum: 2
    maximum: 10
    fallback: 6
  }

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
    if (settingToggle.checked) throw new Error("toggle did not reflect stored false value")
    settingToggle.clicked()
    if (mockController.patches.length !== 1 || mockController.patches[0].enabled !== true || !settingToggle.checked)
      throw new Error("toggle persistence failed")

    var editor = descendant(integerSetting, "integerSettingEditor")
    if (!editor) throw new Error("integer editor is not addressable")
    editor.text = "99"; integerSetting.save()
    editor.text = "0"; integerSetting.save()
    editor.text = "invalid"; integerSetting.save()
    if (mockController.patches.length !== 4) throw new Error("integer persistence event count failed")
    if (mockController.patches[1].interval !== 10) throw new Error("integer maximum clamp failed")
    if (mockController.patches[2].interval !== 2) throw new Error("integer minimum clamp failed")
    if (mockController.patches[3].interval !== 6) throw new Error("integer fallback failed")
    console.log("P2P_QML_SETTINGS_CONTROLS_OK")
    Qt.quit()
  })
}
