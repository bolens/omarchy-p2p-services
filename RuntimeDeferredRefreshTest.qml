import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var applied: []

  P2PDeferredRefresh {
    id: deferred
    onApplyRequested: function(services, fullScan) { root.applied = root.applied.concat([{services:services,fullScan:fullScan}]) }
  }

  Component.onCompleted: Qt.callLater(function() {
    deferred.receive([{id:"first"}], false, true)
    deferred.receive([{id:"latest"}], true, true)
    if (!deferred.pending || root.applied.length !== 0) throw new Error("moving refresh was not deferred")
    if (!deferred.flush() || root.applied.length !== 1 || root.applied[0].services[0].id !== "latest" || root.applied[0].fullScan !== true)
      throw new Error("latest deferred refresh was not flushed")
    if (deferred.flush() || root.applied.length !== 1) throw new Error("empty deferred refresh flushed twice")
    deferred.receive([{id:"immediate"}], false, false)
    if (root.applied.length !== 2 || root.applied[1].services[0].id !== "immediate") throw new Error("stationary refresh was not applied immediately")
    deferred.receive([{id:"stale"}], true, true)
    deferred.receive([{id:"newest"}], false, false)
    if (deferred.pending || deferred.flush() || root.applied.length !== 3 || root.applied[2].services[0].id !== "newest")
      throw new Error("newer immediate refresh did not supersede deferred state")
    console.log("P2P_QML_DEFERRED_REFRESH_OK")
    Qt.quit()
  })
}
