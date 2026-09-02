pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts

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

  P2PSettingsGrid {
    id: settingsGrid
    width: 600
    Item { implicitWidth: 100; implicitHeight: 20 }
    Item { implicitWidth: 100; implicitHeight: 20 }
  }
  ColumnLayout {
    id: narrowGridHost
    width: 400
    P2PSettingsGrid {
      id: constrainedGrid
      IntegerSetting { controller: mockController; settingKey: "interval"; label: "Open-panel refresh interval, seconds"; minimum: 2; maximum: 60; fallback: 5 }
      IntegerSetting { controller: mockController; settingKey: "interval"; label: "Background refresh interval, seconds"; minimum: 2; maximum: 60; fallback: 5 }
    }
  }
  P2PSettingsGrid {
    id: threeColumnGrid
    width: 600
    wideColumns: 3
    Item { implicitWidth: 100; implicitHeight: 20 }
    Item { implicitWidth: 100; implicitHeight: 20 }
    Item { implicitWidth: 100; implicitHeight: 20 }
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
    if (!settingsGrid.twoColumns || settingsGrid.columns !== 2) throw new Error("wide settings field grid did not use horizontal space")
    if (!threeColumnGrid.twoColumns || threeColumnGrid.columns !== 3) throw new Error("wide settings field grid did not honor its column capacity")
    if (constrainedGrid.width > narrowGridHost.width || constrainedGrid.implicitWidth > narrowGridHost.width || constrainedGrid.twoColumns || constrainedGrid.columns !== 1)
      throw new Error("intrinsic child widths prevented a constrained settings grid from collapsing")
    settingsGrid.width = 400
    threeColumnGrid.width = 400
    if (settingsGrid.twoColumns || settingsGrid.columns !== 1) throw new Error("narrow settings field grid did not collapse")
    if (threeColumnGrid.twoColumns || threeColumnGrid.columns !== 1) throw new Error("narrow three-column grid did not collapse")
    if (settingToggle.checked) throw new Error("toggle did not reflect stored false value")
    settingToggle.clicked()
    if (mockController.patches.length !== 1 || mockController.patches[0].enabled !== true || !settingToggle.checked)
      throw new Error("toggle persistence failed")

    var editor = descendant(integerSetting, "integerSettingEditor")
    var saveButton = descendant(integerSetting, "integerSettingSaveButton")
    if (!editor || !saveButton) throw new Error("integer editor is not addressable")
    if (saveButton.text !== "" || saveButton.iconText !== "󰆓" || saveButton.tooltipText !== "Save interval") throw new Error("integer save action is not a descriptive icon control")
    editor.text = "invalid"
    if (saveButton.enabled) throw new Error("invalid integer input left the save action enabled")
    editor.text = "7"
    if (!saveButton.enabled) throw new Error("valid integer input did not enable the save action")
    editor.text = "99"; integerSetting.save()
    editor.text = "0"; integerSetting.save()
    editor.text = "invalid"; integerSetting.save()
    editor.text = "7.8"; integerSetting.save()
    if (mockController.patches.length !== 5) throw new Error("integer persistence event count failed")
    if (mockController.patches[1].interval !== 10) throw new Error("integer maximum clamp failed")
    if (mockController.patches[2].interval !== 2) throw new Error("integer minimum clamp failed")
    if (mockController.patches[3].interval !== 6) throw new Error("integer fallback failed")
    if (mockController.patches[4].interval !== 8) throw new Error("fractional integer input was persisted")
    mockController.values = Object.assign({}, mockController.values, {enabled:false,interval:8})
    Qt.callLater(function() {
      if (settingToggle.checked) throw new Error("toggle ignored externally reloaded settings")
      if (editor.text !== "8") throw new Error("edited integer control ignored externally reloaded settings")
      console.log("P2P_QML_SETTINGS_CONTROLS_OK")
      Qt.quit()
    })
  })
}
