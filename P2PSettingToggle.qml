import QtQuick.Layouts
import qs.Commons
import qs.Ui

Toggle {
  required property var controller
  required property string settingKey
  property bool fallback: true

  Layout.fillWidth: true
  checked: controller.setting(settingKey, fallback) === true
  foreground: Color.popups.text
  accent: Color.bar.active
  fontFamily: Style.font.family
  onClicked: {
    var update = {}
    update[settingKey] = !checked
    controller.persistKeepingOpen(update)
  }
}
