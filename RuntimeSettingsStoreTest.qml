import Quickshell
import QtQuick

ShellRoot {
  id: root
  property bool started: false

  P2PSettingsStore {
    id: store
    helper: "/usr/bin/true"
    moduleName: "p2p-services"
    onRunningChanged: {
      if (!running && root.started) {
        if (store.queuedSettings) throw new Error("queued settings save did not drain")
        console.log("P2P_QML_SETTINGS_STORE_OK")
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("settings store queue test timed out") }
  }

  Component.onCompleted: {
    var adopted = {sortMode:"name"}
    store.adopt(adopted)
    adopted.sortMode = "status"
    if (!store.loaded || store.durableSettings.sortMode !== "name")
      throw new Error("settings adoption was not isolated")

    store.save({sortMode:"name",showIcons:true}, {sortMode:"name"})
    store.save({sortMode:"activity",showIcons:true}, {sortMode:"activity"})
    store.save({sortMode:"activity",showIcons:false}, {showIcons:false})
    if (!store.queuedSettings)
      throw new Error("same-tick settings saves were not queued")
    if (store.queuedSettings.sortMode !== "activity" || store.queuedSettings.showIcons !== false)
      throw new Error("queued settings did not retain the latest state")
    if (store.queuedPatch.sortMode !== "activity" || store.queuedPatch.showIcons !== false)
      throw new Error("queued settings patches were not merged")
    root.started = true
  }
}
