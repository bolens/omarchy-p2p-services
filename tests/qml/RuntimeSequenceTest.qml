import Quickshell
import QtQuick
import "Model.js" as Model

ShellRoot {
  id: root
  property list<var> rows: [{id:"syncthing",backend:"process",active:true}]
  property list<string> command: ["/usr/bin/printf", "sequence-ok"]
  property int deliveries: 0

  P2PDeferredRefresh {
    id: deferred
    onApplyRequested: function(rows, fullScan) {
      var merged = Model.mergeServiceStatus([], rows, fullScan)
      if (merged.length !== 1 || merged[0].id !== "syncthing") throw new Error("status delivery discarded a QML sequence")
      root.deliveries++
    }
  }
  P2PRefreshController {
    id: refresh
    onSucceeded: function(payload, fullScan) {
      if (payload !== "sequence-ok" || !fullScan || root.deliveries !== 1) throw new Error("sequence command or status delivery failed")
      console.log("P2P_QML_SEQUENCE_OK")
      Qt.quit()
    }
    onFailed: function(code) { throw new Error("sequence command failed: " + code) }
  }
  Component.onCompleted: Qt.callLater(function() {
    if (Model.mergeServiceStatus([], root.rows, true).length !== 1) throw new Error("model discarded a QML sequence")
    if (Model.applyLifecycleEvidence(root.rows, {}, Date.now()).length !== 1) throw new Error("lifecycle projection discarded a QML sequence")
    deferred.receive(root.rows, true, false)
    if (!refresh.request(root.command, true, false)) throw new Error("refresh rejected a QML command sequence")
  })
}
