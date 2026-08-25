import QtQuick

QtObject {
  property var uninstallTarget: null
  property bool uninstallOpen: false
  property var restoreTarget: null
  property string restoreBackupName: ""
  property bool restoreOpen: false

  signal uninstallConfirmed(var entry)
  signal restoreConfirmed(var entry, string backupName)

  function requestUninstall(entry) {
    if (!entry) return false
    uninstallTarget = entry
    uninstallOpen = true
    return true
  }
  function cancelUninstall() { uninstallOpen = false; uninstallTarget = null }
  function confirmUninstall() {
    var entry = uninstallTarget
    cancelUninstall()
    if (!entry) return false
    uninstallConfirmed(entry)
    return true
  }
  function requestRestore(entry, backupName) {
    if (!entry || !backupName) return false
    restoreTarget = entry
    restoreBackupName = String(backupName)
    restoreOpen = true
    return true
  }
  function cancelRestore() { restoreOpen = false; restoreTarget = null; restoreBackupName = "" }
  function confirmRestore() {
    var entry = restoreTarget, backupName = restoreBackupName
    cancelRestore()
    if (!entry || !backupName) return false
    restoreConfirmed(entry, backupName)
    return true
  }
  function cancelAll() { cancelUninstall(); cancelRestore() }
}
