pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  property int savedCount: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/settings-helper"))

  P2PSettingsStore {
    id: store
    helper: root.fixtureHelper
    moduleName: "p2p-services"
    onSaved: root.savedCount++
    onReconciled: function(settings) {
      if (root.stage === 0) {
        if (!store.loaded || settings.id !== "p2p-services" || settings.serviceSortMode !== "name") throw new Error("settings reconciliation failed")
        root.stage = 1
        store.save({serviceSortMode:"activity",showGroupIcons:false}, {serviceSortMode:"activity",showGroupIcons:false})
      } else if (root.stage === 4) {
        if (settings.id !== "p2p-services" || settings.serviceSortMode !== "fallback-malformed") throw new Error("malformed load did not retain shell fallback")
        root.stage = 5
        store.helper = "/usr/bin/false"
        store.load({serviceSortMode:"fallback-nonzero"})
      } else if (root.stage === 5) {
        if (settings.id !== "p2p-services" || settings.serviceSortMode !== "fallback-nonzero") throw new Error("failed load did not retain shell fallback")
        if (root.savedCount !== 1) throw new Error("successful durable save drain was not published exactly once")
        root.stage = 6
        console.log("P2P_QML_SETTINGS_STORE_IO_OK")
        Qt.quit()
      } else throw new Error("unexpected settings reconciliation at stage " + root.stage)
    }
    onUpdated: function(settings) {
      if (root.stage !== 1) throw new Error("unexpected settings update")
      if (settings.id !== "p2p-services" || settings.serviceSortMode !== "activity" || settings.showGroupIcons !== false)
        throw new Error("settings patch publication failed")
      root.stage = 2
      Qt.callLater(function() {
        store.helper = "/usr/bin/false"
        store.save({serviceSortMode:"custom"}, null)
      })
    }
    onSaveFailed: {
      if (root.stage === 2) {
        root.stage = 3
        store.helper = root.fixtureHelper
        store.save({malformedPatch:true}, {malformedPatch:true})
      } else if (root.stage === 3) {
        if (store.durableSettings.serviceSortMode !== "activity") throw new Error("malformed patch did not restore durable settings")
        root.stage = 4
        store.load({failureMode:"malformed-load",serviceSortMode:"fallback-malformed"})
      } else throw new Error("unexpected settings save failure at stage " + root.stage)
    }
    onLoadFailed: if (root.stage !== 4 && root.stage !== 5) throw new Error("unexpected settings load failure")
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("settings store I/O test timed out at stage " + root.stage) }
  }

  Component.onCompleted: {
    if (!store.load({serviceSortMode:"custom"})) throw new Error("settings reconciliation did not report its start")
    if (store.load({serviceSortMode:"superseded"})) throw new Error("duplicate settings reconciliation was accepted")
    if (!store.loading) throw new Error("active settings reconciliation was not observable")
    if (store.save({serviceSortMode:"racing"}, {serviceSortMode:"racing"}) !== false)
      throw new Error("settings save overlapped active reconciliation")
    if (store.durableSettings.serviceSortMode === "racing") throw new Error("rejected overlapping save changed durable state")
  }
}
