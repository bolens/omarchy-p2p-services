import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int requests: 0

  P2PServiceActions {
    id: actions
    helper: "/opt/p2p-helper"
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
    console.log("P2P_QML_SERVICE_ACTIONS_OK")
    Qt.quit()
  })
}
