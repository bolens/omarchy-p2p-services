pragma ComponentBehavior: Bound
import Quickshell
import QtQuick

ShellRoot {
  id: root
  property int failures: 0

  P2PSettingsStore {
    id: store
    helper: "/usr/bin/false"
    moduleName: "p2p-services"
    onSaved: { throw new Error("failed queued settings save emitted success") }
    onSaveFailed: {
      root.failures += 1
      if (root.failures === 2) Qt.callLater(function() {
        if (store.running || store.queuedSettings || store.queuedPatch || store.queuedFallback)
          throw new Error("failed settings queue did not return to idle")
        if (store.durableSettings.mode !== "durable")
          throw new Error("failed settings queue restored optimistic state instead of durable state: " + JSON.stringify(store.durableSettings))
        console.log("P2P_QML_SETTINGS_STORE_QUEUE_FAILURE_OK")
        Qt.quit()
      })
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("queued settings failure test timed out after " + root.failures + " failures") } }

  Component.onCompleted: {
    store.adopt({id:"p2p-services",mode:"durable"})
    store.save({id:"p2p-services",mode:"first-optimistic"}, {mode:"first-optimistic"})
    store.save({id:"p2p-services",mode:"second-optimistic"}, {mode:"second-optimistic"})
    if (!store.running || !store.queuedSettings || store.queuedSettings.mode !== "second-optimistic")
      throw new Error("second settings save was not queued")
  }
}
