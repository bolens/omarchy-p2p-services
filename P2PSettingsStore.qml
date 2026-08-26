import QtQuick
import Quickshell.Io

QtObject {
  id: store
  required property string helper
  required property string moduleName
  property var durableSettings: ({})
  property var queuedSettings: null
  property var queuedPatch: null
  property var queuedFallback: null
  property var loadFallback: ({})
  property var activeSaveFallback: ({})
  property bool loaded: false
  property bool busy: false
  property bool loadBusy: false
  property bool loadTimedOut: false
  property bool saveTimedOut: false
  property int timeoutMilliseconds: 15000
  readonly property bool running: busy
  readonly property bool loading: loadBusy

  signal reconciled(var settings)
  signal loadFailed()
  signal saveFailed()
  signal saved()
  signal updated(var settings)

  function load(shellSettings) {
    if (loading || String(helper || "").trim() === "") return false
    loadBusy = true
    loadTimedOut = false
    loadFallback = JSON.parse(JSON.stringify(shellSettings || {}))
    loadProc.command = [helper, "settings-reconcile", JSON.stringify(shellSettings || {})]
    loadProc.running = true
    loadWatchdog.start()
    return true
  }

  function save(next, patch) {
    var previous = JSON.parse(JSON.stringify(durableSettings || {}))
    durableSettings = JSON.parse(JSON.stringify(next || {}))
    if (busy) {
      queuedSettings = durableSettings
      if (queuedFallback === null) queuedFallback = previous
      if (patch) {
        var merged = queuedPatch || {}
        for (var key in patch) merged[key] = patch[key]
        queuedPatch = merged
      } else queuedPatch = null
      return
    }
    startSave(durableSettings, patch, previous)
  }

  function startSave(next, patch, fallback) {
    busy = true
    saveTimedOut = false
    activeSaveFallback = JSON.parse(JSON.stringify(fallback || {}))
    saveProc.patchMode = !!patch
    saveProc.command = [helper, patch ? "settings-patch" : "settings-save", JSON.stringify(patch || durableSettings)]
    saveProc.running = true
    saveWatchdog.start()
  }

  function adopt(next) { durableSettings = JSON.parse(JSON.stringify(next || {})); loaded = true }

  property Process loadProc: Process {
    stdout: StdioCollector { id: loadOutput; waitForEnd: true }
    onExited: function(exitCode) {
        loadWatchdog.stop()
        store.loadBusy = false
        var stored = null
        if (exitCode === 0 && !store.loadTimedOut) {
        try {
          var parsed = JSON.parse(String(loadOutput.text || ""))
          if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) stored = parsed
        } catch (error) {}
        }
        if (!stored) {
          stored = JSON.parse(JSON.stringify(store.loadFallback || {}))
          store.loadFailed()
        }
        var merged = {}
        for (var key in stored) if (key !== "id") merged[key] = stored[key]
        merged.id = store.moduleName
        store.durableSettings = merged
        store.loaded = true
        store.reconciled(merged)
    }
  }

  property Process saveProc: Process {
    property bool patchMode: false
    stdout: StdioCollector { id: saveOutput; waitForEnd: true }
    onExited: function(exitCode) {
      saveWatchdog.stop()
      var failed = exitCode !== 0 || store.saveTimedOut
      if (!failed && patchMode) {
        var valid = false
        try {
          var parsed = JSON.parse(String(saveOutput.text || ""))
          if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
            valid = true
            parsed.id = store.moduleName
            store.durableSettings = parsed
            store.updated(parsed)
          }
        } catch (error) {}
        if (!valid) failed = true
      }
      if (failed) {
        store.durableSettings = JSON.parse(JSON.stringify(store.activeSaveFallback || {}))
        store.saveFailed()
      }
      if (store.queuedSettings) {
        var next = store.queuedSettings
        var patch = store.queuedPatch
        var fallback = failed ? store.activeSaveFallback : store.queuedFallback
        store.queuedSettings = null
        store.queuedPatch = null
        store.queuedFallback = null
        store.durableSettings = next
        Qt.callLater(function() { store.startSave(next, patch, fallback) })
      } else {
        store.busy = false
        if (!failed) store.saved()
      }
    }
  }
  property P2PProcessWatchdog loadWatchdog: P2PProcessWatchdog {
    process: store.loadProc
    timeoutMilliseconds: store.timeoutMilliseconds
    onTimedOut: store.loadTimedOut = true
  }
  property P2PProcessWatchdog saveWatchdog: P2PProcessWatchdog {
    process: store.saveProc
    timeoutMilliseconds: store.timeoutMilliseconds
    onTimedOut: store.saveTimedOut = true
  }
}
