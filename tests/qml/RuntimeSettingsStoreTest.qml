pragma ComponentBehavior: Bound
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

    store.helper = "   "
    if (store.save({sortMode:"invalid"}, {sortMode:"invalid"}) !== false) throw new Error("blank settings helper save was accepted")
    if (store.running || store.durableSettings.sortMode !== "name") throw new Error("blank settings helper changed durable state")
    store.helper = "/usr/bin/true"
    store.save({sortMode:"name",showIcons:true}, {sortMode:"name"})
    if (store.load({sortMode:"racing"})) throw new Error("settings reconciliation overlapped active save")
    if (store.loading) throw new Error("rejected overlapping reconciliation changed load state")
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
