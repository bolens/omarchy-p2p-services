import QtQuick
import Quickshell

QtObject {
  id: actions
  required property string helper
  property bool privacyFiltered: true
  property bool autoStartAfterInstall: false
  property int backupRetention: 10

  signal notifyRequested(string title, string body)
  signal catalogTrackingRequested()
  signal actionRequested(var entry, string action, var command)

  function openConsole(entry, url) {
    if (url) { Quickshell.execDetached([helper, "open-url", url]); return true }
    if (entry && entry.hasWeb === true) { Quickshell.execDetached([helper, "action", entry.id, "open"]); return true }
    return false
  }

  function openLogs(entry) {
    if (entry) Quickshell.execDetached(["omarchy-launch-terminal", helper, "logs", entry.id])
  }

  function copyDiagnostics(entry, label) {
    if (!entry) return
    Quickshell.execDetached([helper, "copy-diagnostics", entry.id, privacyFiltered ? "private" : "unsafe"])
    notifyRequested("P2P diagnostics", "Copied " + label + " diagnostics to the clipboard")
  }

  function install(entry) {
    if (!entry || !entry.id) return
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "install", entry.id, autoStartAfterInstall ? "start" : "no-start"])
    catalogTrackingRequested()
    notifyRequested("P2P service installer", "Installing " + entry.name + " through Omarchy")
  }

  function uninstall(entry, label) {
    if (!entry) return
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "uninstall", entry.id, String(backupRetention)])
    catalogTrackingRequested()
    notifyRequested("P2P service uninstaller", "Uninstalling " + label + " through Omarchy; configuration will be backed up")
  }

  function restore(entry, backupName, label) {
    if (!entry || !backupName) return
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "restore-backup", entry.id, backupName])
    notifyRequested("P2P configuration", "Restoring the latest " + label + " backup")
  }

  function control(entry, action) {
    if (entry && !(entry.controllable === false && ["start","stop","restart","config"].indexOf(action) >= 0))
      actionRequested(entry, action, [helper, "action", entry.id, action])
  }
}
