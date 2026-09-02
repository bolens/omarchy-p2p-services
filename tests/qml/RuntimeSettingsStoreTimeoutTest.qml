pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  property int loadFailures: 0
  readonly property string slowHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/settings-slow-helper"))
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/settings-helper"))

  P2PSettingsStore {
    id: store
    helper: root.slowHelper
    moduleName: "p2p-services"
    timeoutMilliseconds: 100
    onLoadFailed: {
      root.loadFailures += 1
      if (root.stage !== 0 || store.loading) throw new Error("timed-out settings load retained active state")
    }
    onReconciled: function(settings) {
      if (root.stage === 0) {
        if (root.loadFailures !== 1 || !store.loadTimedOut || settings.id !== "p2p-services" || settings.serviceSortMode !== "fallback")
          throw new Error("timed-out settings load did not publish its fallback")
        root.stage = 1
        store.helper = root.fixtureHelper
        if (!store.load({serviceSortMode:"recovery-fallback"})) throw new Error("settings load did not recover after timeout")
      } else if (root.stage === 1) {
        if (store.loadTimedOut || settings.serviceSortMode !== "name") throw new Error("successful settings reload retained timeout state")
        root.stage = 2
        store.adopt({id:"p2p-services",mode:"durable"})
        store.helper = root.slowHelper
        if (!store.save({id:"p2p-services",mode:"optimistic"}, null)) throw new Error("slow settings save did not start")
      } else throw new Error("unexpected settings reconciliation stage " + root.stage)
    }
    onSaveFailed: {
      if (root.stage !== 2 || store.running || !store.saveTimedOut || store.durableSettings.mode !== "durable")
        throw new Error("timed-out settings save did not restore durable state")
      root.stage = 3
      store.helper = root.fixtureHelper
      if (!store.save({id:"p2p-services",mode:"recovered"}, null)) throw new Error("settings save did not recover after timeout")
    }
    onSaved: {
      if (root.stage !== 3 || store.running || store.saveTimedOut || store.durableSettings.mode !== "recovered")
        throw new Error("successful settings save retained timeout state")
      root.stage = 4
      console.log("P2P_QML_SETTINGS_STORE_TIMEOUT_OK")
      Qt.quit()
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("settings store timeout test stalled at stage " + root.stage) } }
  Component.onCompleted: if (!store.load({serviceSortMode:"fallback"})) throw new Error("slow settings load did not start")
}
