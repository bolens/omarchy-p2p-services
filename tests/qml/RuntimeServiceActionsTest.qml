import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int requests: 0
  property int notifications: 0
  property int catalogRequests: 0

  P2PServiceActions {
    id: actions
    helper: "/opt/p2p-helper"
    onNotifyRequested: root.notifications += 1
    onCatalogTrackingRequested: root.catalogRequests += 1
    onActionRequested: function(entry, action, command) {
      root.requests += 1
      if (entry.id !== "syncthing" || action !== "restart") throw new Error("service action payload failed")
      if (command.length !== 4 || command[0] !== "/opt/p2p-helper" || command[1] !== "action" || command[2] !== "syncthing" || command[3] !== "restart")
        throw new Error("service action command failed")
    }
  }

  Component.onCompleted: Qt.callLater(function() {
    actions.control({id:"syncthing"}, "restart")
    actions.control(null, "stop")
    actions.control({}, "stop")
    actions.control({id:"syncthing"}, "")
    actions.control({id:"syncthing"}, "delete")
    if (root.requests !== 1) throw new Error("invalid service action was dispatched")
    if (actions.openConsole({hasWeb:false}, "") !== false) throw new Error("missing console was reported as opened")
    if (actions.openConsole({hasWeb:true}, "") !== false) throw new Error("console action without a service id was reported as opened")
    if (actions.openConsole({hasWeb:false}, "   ") !== false) throw new Error("blank console URL was reported as opened")
    if (actions.openLogs({}) || actions.copyDiagnostics({}, "Unknown") || actions.uninstall({}, "Unknown")
        || actions.restore({}, "backup-1", "Unknown")) throw new Error("service action without an id was accepted")
    if (root.notifications !== 0 || root.catalogRequests !== 0) throw new Error("invalid service action emitted side effects")
    actions.helper = "   "
    if (actions.openConsole({id:"syncthing",hasWeb:true}, "") || actions.openConsole({id:"syncthing"}, "https://sync.example.test")
        || actions.openLogs({id:"syncthing"}) || actions.copyDiagnostics({id:"syncthing"}, "Syncthing")
        || actions.install({id:"syncthing",name:"Syncthing"}) || actions.uninstall({id:"syncthing"}, "Syncthing")
        || actions.restore({id:"syncthing"}, "backup-1", "Syncthing")) throw new Error("blank service helper was accepted")
    actions.control({id:"syncthing"}, "restart")
    if (root.requests !== 1 || root.notifications !== 0 || root.catalogRequests !== 0) throw new Error("blank helper action emitted side effects")
    console.log("P2P_QML_SERVICE_ACTIONS_OK")
    Qt.quit()
  })
}
