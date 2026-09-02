import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  readonly property string slowHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/settings-slow-helper"))

  P2PSettingsStore {
    id: store
    helper: root.slowHelper
    moduleName: "p2p-services"
    onSaveFailed: { throw new Error("mixed settings queue unexpectedly failed") }
    onSaved: {
      if (store.durableSettings.mode !== "latest" || store.durableSettings.preserved !== true)
        throw new Error("patch after queued full save dropped snapshot fields: " + JSON.stringify(store.durableSettings))
      console.log("P2P_QML_SETTINGS_STORE_MIXED_QUEUE_OK")
      Qt.quit()
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("mixed settings queue test timed out") } }

  Component.onCompleted: {
    store.adopt({id:"p2p-services",mode:"durable"})
    store.save({id:"p2p-services",mode:"active"}, {mode:"active"})
    store.save({id:"p2p-services",mode:"full",preserved:true}, null)
    store.save({id:"p2p-services",mode:"latest",preserved:true}, {mode:"latest"})
  }
}
