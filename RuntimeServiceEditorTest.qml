import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string editingServiceId: "syncthing"
    property bool privacyFilter: true
    property var events: []
    property var currentService: ({id:"syncthing",name:"Syncthing",backend:"systemd",active:false,configExists:false,unit:"syncthing.service",backups:[]})
    function service(_id) { return currentService }
    function labelFor(_entry) { return "Home Sync" }
    function iconFor(_entry) { return "S" }
    function isFavorite(_id) { return false }
    function serviceShowsStopped(_id) { return true }
    function serviceNotificationPolicy(_id) { return "inherit" }
    function consoleUrl(_entry) { return "https://sync.example.test" }
    function catalogEntry(_id) { return {backups:[]} }
    function hasConsole(_entry) { return true }
    function canUninstall(_entry) { return false }
    function persistServiceMap(key, id, value, removeEmpty) { events = events.concat([{kind:"map",key:key,id:id,value:value,removeEmpty:removeEmpty}]) }
    function saveConsoleUrl(id, value) { events = events.concat([{kind:"console",id:id,value:value}]) }
    function toggleFavorite(_id) {}
    function moveService(_id, _delta) {}
    function act(_entry, _action) {}
    function openConsole(_entry) {}
    function requestRestore(_entry, _name) {}
    function resetService(_id) {}
    function requestUninstall(_entry) {}
  }

  P2PServiceEditor { id: editor; controller: mockController }

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
    var label = descendant(editor, "serviceLabelEditor")
    var icon = descendant(editor, "serviceIconEditor")
    var policy = descendant(editor, "serviceNotificationPolicyDropdown")
    var consoleEditor = descendant(editor, "serviceConsoleEditor")
    var configButton = descendant(editor, "serviceConfigButton")
    if (!label || !icon || !policy || !consoleEditor || !configButton) throw new Error("service editor controls are not addressable")
    label.text = "Family Sync"; label.accepted()
    icon.text = "F"; icon.accepted()
    policy.changed("failures")
    consoleEditor.text = "https://family.example.test"; consoleEditor.accepted()
    var events = mockController.events
    if (events.length !== 4) throw new Error("service editor event count mismatch")
    if (events[0].key !== "serviceLabels" || events[0].value !== "Family Sync" || events[0].removeEmpty !== true) throw new Error("label edit event failed")
    if (events[1].key !== "serviceIcons" || events[1].value !== "F" || events[1].removeEmpty !== true) throw new Error("icon edit event failed")
    if (events[2].key !== "serviceNotificationPolicies" || events[2].value !== "failures" || events[2].removeEmpty !== false) throw new Error("notification policy event failed")
    if (events[3].kind !== "console" || events[3].value !== "https://family.example.test") throw new Error("console edit event failed")
    mockController.currentService = Object.assign({}, mockController.currentService, {configExists:true,controllable:false})
    Qt.callLater(function() {
      if (configButton.visible) throw new Error("observation-only service exposed config mutation")
      console.log("P2P_QML_SERVICE_EDITOR_OK")
      Qt.quit()
    })
  })
}
