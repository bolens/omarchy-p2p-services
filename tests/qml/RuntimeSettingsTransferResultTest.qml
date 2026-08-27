import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var events: []
  property string error: ""

  QtObject {
    id: mockController
    function persistKeepingOpen(settings) { root.events = root.events.concat([{kind:"import",settings:settings}]) }
    function adoptTransferredSettings(settings) { root.events = root.events.concat([{kind:"undo",settings:settings}]) }
    function notify(title, body) { root.events = root.events.concat([{kind:"notify",title:title,body:body}]) }
  }

  P2PSettingsTransferResult {
    id: result
    controller: mockController
    moduleName: "p2p-services"
    onErrorRequested: function(message) { root.error = message }
  }

  Component.onCompleted: Qt.callLater(function() {
    if (!result.apply("import", '{"id":"another-plugin","popupWidth":700}')) throw new Error("valid import was rejected")
    if (root.events[0].kind !== "import" || root.events[0].settings.id !== "p2p-services" || root.events[0].settings.popupWidth !== 700 || root.events[1].kind !== "notify")
      throw new Error("import result application failed")
    if (!result.apply("undo", '{"popupWidth":650}')) throw new Error("valid undo was rejected")
    if (root.events[2].kind !== "undo" || root.events[2].settings.id !== "p2p-services" || root.events[3].kind !== "notify")
      throw new Error("undo result application failed")
    if (result.apply("import", "[]") || root.error !== "Imported settings are invalid") throw new Error("invalid import was accepted")
    if (!result.apply("export", "") || root.events[4].kind !== "notify" || root.events[4].body.indexOf("settings-export.json") < 0)
      throw new Error("export result notification failed")
    console.log("P2P_QML_SETTINGS_TRANSFER_RESULT_OK")
    Qt.quit()
  })
}
