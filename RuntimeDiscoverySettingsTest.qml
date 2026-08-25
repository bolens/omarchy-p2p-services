import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "discovery"
    property bool settingsTransferRunning: false
    property bool settingsTransferLoading: true
    property var patches: []
    property var calls: []
    function setting(key, fallback) {
      var values = {consoleHost:"old.example.test",enabledServices:["syncthing"],customServices:[]}
      return values[key] === undefined ? fallback : values[key]
    }
    function settingsTransferLabel() { return "IMPORTING SETTINGS" }
    function themeColor(_role, fallback) { return fallback }
    function persistKeepingOpen(patch) { patches = patches.concat([patch]) }
    function saveCustomServices(text) { calls = calls.concat([{kind:"custom",value:text}]) }
    function exportSettings() { calls = calls.concat([{kind:"export"}]) }
    function importSettings() { calls = calls.concat([{kind:"import"}]) }
    function undoSettings() { calls = calls.concat([{kind:"undo"}]) }
  }

  P2PDiscoverySettings { id: page; controller: mockController }

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
    var host = descendant(page, "consoleHostEditor")
    var allowlist = descendant(page, "serviceAllowlistEditor")
    var allowlistSave = descendant(page, "serviceAllowlistSaveButton")
    var custom = descendant(page, "customServicesEditor")
    var customSave = descendant(page, "customServicesSaveButton")
    var exportButton = descendant(page, "settingsExportButton")
    var importButton = descendant(page, "settingsImportButton")
    var undoButton = descendant(page, "settingsUndoButton")
    var transferLoading = descendant(page, "settingsTransferLoadingIndicator")
    if (!host || !allowlist || !allowlistSave || !custom || !customSave || !exportButton || !importButton || !undoButton || !transferLoading)
      throw new Error("discovery settings controls are not addressable")
    if (!transferLoading.visible || transferLoading.label !== "IMPORTING SETTINGS") throw new Error("settings transfer loading presentation failed")
    mockController.settingsTransferLoading = false
    if (transferLoading.visible) throw new Error("settings transfer loading presentation did not settle")
    host.text = " node.home.arpa "; host.accepted()
    allowlist.text = "syncthing, tailscale,  , headscale"; allowlistSave.clicked()
    custom.text = '[{"id":"mesh"}]'; customSave.clicked()
    exportButton.clicked(); importButton.clicked(); undoButton.clicked()
    if (mockController.patches.length !== 2) throw new Error("discovery persistence event count failed")
    if (mockController.patches[0].consoleHost !== "node.home.arpa") throw new Error("console host normalization failed")
    var ids = mockController.patches[1].enabledServices
    if (ids.length !== 3 || ids[0] !== "syncthing" || ids[1] !== "tailscale" || ids[2] !== "headscale")
      throw new Error("service allowlist parsing failed")
    if (mockController.calls.length !== 4 || mockController.calls[0].value !== '[{"id":"mesh"}]' || mockController.calls[1].kind !== "export" || mockController.calls[2].kind !== "import" || mockController.calls[3].kind !== "undo")
      throw new Error("discovery command dispatch failed")
    console.log("P2P_QML_DISCOVERY_SETTINGS_OK")
    Qt.quit()
  })
}
