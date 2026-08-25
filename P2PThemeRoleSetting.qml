import QtQuick.Layouts
import qs.Commons
import qs.Ui

Dropdown {
  required property var controller
  required property string settingKey
  required property string label
  required property string fallback
  objectName: "themeRole-" + settingKey
  Layout.fillWidth: true
  value: String(controller.setting(settingKey, fallback))
  options: [{value:"bar-active",label:"Bar active"},{value:"urgent",label:"Urgent"},{value:"accent",label:"Accent"},{value:"foreground",label:"Foreground"},{value:"muted",label:"Muted"}]
  foreground: Color.popups.text
  accent: Color.bar.active
  onChanged: function(next) { var update = {}; update[settingKey] = next; controller.persistKeepingOpen(update) }
}
