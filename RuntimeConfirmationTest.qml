import Quickshell
import QtQuick

ShellRoot {
  id: root
  property var events: []

  P2PServiceConfirmationController {
    id: confirmations
    onUninstallConfirmed: function(entry) { root.events = root.events.concat([{kind:"uninstall",id:entry.id}]) }
    onRestoreConfirmed: function(entry, backupName) { root.events = root.events.concat([{kind:"restore",id:entry.id,backup:backupName}]) }
  }

  Component.onCompleted: {
    if (confirmations.requestUninstall(null)) throw new Error("invalid uninstall confirmation opened")
    if (!confirmations.requestUninstall({id:"syncthing"}) || !confirmations.uninstallOpen) throw new Error("uninstall confirmation did not open")
    confirmations.cancelUninstall()
    if (confirmations.uninstallOpen || confirmations.uninstallTarget) throw new Error("uninstall cancellation did not clear state")
    confirmations.requestUninstall({id:"syncthing"}); confirmations.confirmUninstall()
    if (root.events.length !== 1 || root.events[0].kind !== "uninstall" || confirmations.uninstallOpen) throw new Error("uninstall confirmation failed")

    if (confirmations.requestRestore({id:"syncthing"}, "")) throw new Error("invalid restore confirmation opened")
    confirmations.requestRestore({id:"syncthing"}, "backup-1")
    confirmations.confirmRestore()
    if (root.events.length !== 2 || root.events[1].backup !== "backup-1" || confirmations.restoreOpen || confirmations.restoreTarget)
      throw new Error("restore confirmation failed")
    confirmations.requestUninstall({id:"tailscale"})
    confirmations.requestRestore({id:"tailscale"}, "backup-2")
    if (confirmations.uninstallOpen || !confirmations.restoreOpen) throw new Error("restore confirmation did not replace uninstall confirmation")
    confirmations.requestUninstall({id:"tailscale"})
    if (!confirmations.uninstallOpen || confirmations.restoreOpen || confirmations.restoreTarget || confirmations.restoreBackupName !== "")
      throw new Error("uninstall confirmation did not replace restore confirmation")
    confirmations.cancelAll()
    if (confirmations.uninstallOpen || confirmations.restoreOpen || confirmations.uninstallTarget || confirmations.restoreTarget || confirmations.restoreBackupName !== "")
      throw new Error("confirmation close cleanup failed")
    console.log("P2P_QML_CONFIRMATION_OK")
    Qt.quit()
  }
}
