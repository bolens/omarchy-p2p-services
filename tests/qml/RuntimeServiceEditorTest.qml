pragma ComponentBehavior: Bound
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
    property var navigation: []
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
    function canMoveServiceEditor(_id, delta) { return delta === 1 }
    function moveServiceEditor(delta) { navigation = navigation.concat([delta]) }
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
    var labelSave = descendant(editor, "serviceLabelSaveButton")
    var iconSave = descendant(editor, "serviceIconSaveButton")
    var consoleSave = descendant(editor, "serviceConsoleSaveButton")
    var restore = descendant(editor, "serviceRestoreButton")
    var reset = descendant(editor, "serviceResetButton")
    var uninstall = descendant(editor, "serviceUninstallButton")
    var back = descendant(editor, "serviceEditorBackButton")
    var title = descendant(editor, "serviceEditorTitle")
    var previous = descendant(editor, "serviceEditorPreviousButton")
    var next = descendant(editor, "serviceEditorNextButton")
    if (!label || !icon || !policy || !consoleEditor || !configButton || !moveUp || !moveDown || !labelSave || !iconSave || !consoleSave || !restore || !reset || !uninstall || !back || !title || !previous || !next) throw new Error("service editor controls are not addressable")
    if (labelSave.text !== "" || labelSave.tooltipText !== "Save service label" || iconSave.text !== "" || iconSave.tooltipText !== "Save service icon" || consoleSave.text !== "" || consoleSave.tooltipText !== "Save console URL") throw new Error("service editor save actions are not descriptive icon controls")
    if (moveUp.text !== "" || moveUp.tooltipText !== "Move service up" || moveDown.text !== "" || moveDown.tooltipText !== "Move service down" || configButton.text !== "" || configButton.tooltipText !== "Open service configuration") throw new Error("service editor navigation actions are not descriptive icon controls")
    if (title.text !== "Home Sync settings" || previous.enabled || !next.enabled) throw new Error("service editor navigation state is wrong")
    next.clicked()
    if (mockController.navigation.length !== 1 || mockController.navigation[0] !== 1) throw new Error("service editor navigation action failed")
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
    if (uninstall.enabled || restore.enabled || restore.tooltipText !== "Stop the service before restoring configuration") throw new Error("running service exposed maintenance mutation")
    var activeEventCount = mockController.events.length
    restore.clicked()
    if (mockController.events.length !== activeEventCount) throw new Error("disabled restore action dispatched while service was running")
    mockController.currentService = Object.assign({}, mockController.currentService, {configExists:true,controllable:false})
    Qt.callLater(function() {
      if (configButton.visible) throw new Error("observation-only service exposed config mutation")
      console.log("P2P_QML_SERVICE_EDITOR_OK")
      Qt.quit()
    })
  })
}
