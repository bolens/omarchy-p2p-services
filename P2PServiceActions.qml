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

  function hasHelper() { return String(helper || "").trim() !== "" }
  function openConsole(entry, url) {
    var configuredUrl = String(url || "").trim()
    if (!hasHelper()) return false
    if (configuredUrl) { Quickshell.execDetached([helper, "open-url", configuredUrl]); return true }
    if (entry && entry.id && entry.hasWeb === true) { Quickshell.execDetached([helper, "action", entry.id, "open"]); return true }
    return false
  }

  function openLogs(entry) {
    if (!hasHelper() || !entry || !entry.id) return false
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "logs", entry.id])
    return true
  }

  function copyDiagnostics(entry, label) {
    if (!hasHelper() || !entry || !entry.id) return false
    Quickshell.execDetached([helper, "copy-diagnostics", entry.id, privacyFiltered ? "private" : "unsafe"])
    notifyRequested("P2P diagnostics", "Copied " + label + " diagnostics to the clipboard")
    return true
  }

  function install(entry) {
    if (!hasHelper() || !entry || !entry.id) return false
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "install", entry.id, autoStartAfterInstall ? "start" : "no-start"])
    catalogTrackingRequested()
    notifyRequested("P2P service installer", "Installing " + entry.name + " through Omarchy")
    return true
  }

  function uninstall(entry, label) {
    if (!hasHelper() || !entry || !entry.id) return false
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "uninstall", entry.id, String(backupRetention)])
    catalogTrackingRequested()
    notifyRequested("P2P service uninstaller", "Uninstalling " + label + " through Omarchy; configuration will be backed up")
    return true
  }

  function restore(entry, backupName, label) {
    if (!hasHelper() || !entry || !entry.id || !backupName) return false
    Quickshell.execDetached(["omarchy-launch-terminal", helper, "restore-backup", entry.id, backupName])
    notifyRequested("P2P configuration", "Restoring the latest " + label + " backup")
    return true
  }

  function control(entry, action) {
    if (hasHelper() && entry && entry.id && ["start","stop","restart","config"].indexOf(action) >= 0 && entry.controllable !== false)
      actionRequested(entry, action, [helper, "action", entry.id, action])
  }
}
