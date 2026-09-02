pragma ComponentBehavior: Bound
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Dropdown {
  id: roleSetting
  required property var controller
  required property string settingKey
  required property string fallback
  readonly property var allowedRoles: ["bar-active","urgent","accent","foreground","muted"]
  function normalizedRole(role) {
    var candidate = String(role)
    return allowedRoles.indexOf(candidate) >= 0 ? candidate : fallback
  }
  objectName: "themeRole-" + settingKey
  Layout.fillWidth: true
  value: normalizedRole(controller.setting(settingKey, fallback))
  options: [{value:"bar-active",label:"Bar active"},{value:"urgent",label:"Urgent"},{value:"accent",label:"Accent"},{value:"foreground",label:"Foreground"},{value:"muted",label:"Muted"}]
  foreground: Color.popups.text
  accent: Color.bar.active
  onChanged: function(next) {
    if (allowedRoles.indexOf(String(next)) < 0) return
    var update = {}; update[settingKey] = next; controller.persistKeepingOpen(update)
  }
}
