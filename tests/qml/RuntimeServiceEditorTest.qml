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
    function catalogEntry(_id) { return {backups:[{name:"backup-1",timestamp:"2026-08-26T12:00:00Z"}]} }
    function hasConsole(_entry) { return true }
    function canUninstall(_entry) { return true }
    function persistServiceMap(key, id, value, removeEmpty) { events = events.concat([{kind:"map",key:key,id:id,value:value,removeEmpty:removeEmpty}]) }
    function saveConsoleUrl(id, value) { events = events.concat([{kind:"console",id:id,value:value}]) }
    function toggleFavorite(_id) {}
    function moveService(id, delta) { events = events.concat([{kind:"move",id:id,delta:delta}]) }
    function act(_entry, _action) {}
    function openConsole(_entry) {}
    function requestRestore(entry, name) { events = events.concat([{kind:"restore",id:entry.id,name:name}]) }
    function resetService(id) { events = events.concat([{kind:"reset",id:id}]) }
    function requestUninstall(entry) { events = events.concat([{kind:"uninstall",id:entry.id}]) }
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
    var moveUp = descendant(editor, "serviceMoveUpButton")
    var moveDown = descendant(editor, "serviceMoveDownButton")
    var restore = descendant(editor, "serviceRestoreButton")
    var reset = descendant(editor, "serviceResetButton")
    var uninstall = descendant(editor, "serviceUninstallButton")
    if (!label || !icon || !policy || !consoleEditor || !configButton || !moveUp || !moveDown || !restore || !reset || !uninstall) throw new Error("service editor controls are not addressable")
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
    moveUp.clicked(); moveDown.clicked(); restore.clicked(); reset.clicked(); uninstall.clicked()
    events = mockController.events
    if (events.length !== 9 || events[4].delta !== -1 || events[5].delta !== 1) throw new Error("service ordering actions failed: " + JSON.stringify(events))
    if (events[6].kind !== "restore" || events[6].name !== "backup-1" || events[7].kind !== "reset" || events[8].kind !== "uninstall") throw new Error("service maintenance actions failed")
    mockController.currentService = Object.assign({}, mockController.currentService, {active:true})
    if (uninstall.enabled) throw new Error("running service exposed uninstall action")
    mockController.currentService = Object.assign({}, mockController.currentService, {configExists:true,controllable:false})
    Qt.callLater(function() {
      if (configButton.visible) throw new Error("observation-only service exposed config mutation")
      console.log("P2P_QML_SERVICE_EDITOR_OK")
      Qt.quit()
    })
  })
}
