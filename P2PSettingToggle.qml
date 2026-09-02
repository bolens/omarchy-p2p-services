pragma ComponentBehavior: Bound
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Ui

Toggle {
  required property var controller
  required property string settingKey
  property bool fallback: true
  property string tooltipText: ""
  property bool tooltipHovered: false

  Layout.fillWidth: true
  checked: controller.setting(settingKey, fallback) === true
  foreground: Color.popups.text
  accent: Color.bar.active
  fontFamily: Style.font.family
  ToolTip.visible: tooltipText !== "" && tooltipHovered
  ToolTip.text: tooltipText
  ToolTip.delay: 500
  onHovered: function(isHovered) { tooltipHovered = isHovered }
  onClicked: {
    var update = {}
    update[settingKey] = !checked
    controller.persistKeepingOpen(update)
  }
}
