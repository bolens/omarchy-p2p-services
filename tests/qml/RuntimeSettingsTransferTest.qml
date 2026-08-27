import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/transfer-helper"))
  readonly property string failingHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/transfer-failing-helper"))
  readonly property string longFailingHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/action-failing-helper"))

  P2PSettingsTransferController {
    id: transfer
    helper: root.fixtureHelper
    onSucceeded: function(mode, payload) {
      if (root.stage !== 0 || mode !== "export" || payload !== "export-ok") throw new Error("settings transfer success payload failed")
      if (transfer.running) throw new Error("settings transfer remained busy before success publication")
      if (transfer.activeMode !== "") throw new Error("completed settings transfer mode was retained during publication")
      root.stage = 1
      if (transfer.request("invalid")) throw new Error("invalid settings transfer mode started")
      transfer.helper = root.failingHelper
      if (!transfer.request("undo")) throw new Error("failing settings transfer did not start")
    }
    onFailed: function(mode, exitCode, detail) {
      if (root.stage === 1) {
        if (mode !== "undo" || exitCode === 0) throw new Error("settings transfer failure payload failed")
        if (detail !== "fixture transfer failed safely") throw new Error("settings transfer stderr detail was not preserved")
        if (transfer.running) throw new Error("settings transfer remained busy after failure")
        root.stage = 2
        transfer.helper = root.longFailingHelper
        if (!transfer.request("import")) throw new Error("settings transfer did not recover after failure")
      } else if (root.stage === 2) {
        if (mode !== "import" || exitCode === 0 || detail.length !== 512 || detail.charAt(511) !== "x")
          throw new Error("settings transfer stderr was not bounded")
        if (transfer.running) throw new Error("settings transfer remained busy after bounded failure")
        root.stage = 3
        console.log("P2P_QML_SETTINGS_TRANSFER_OK")
        Qt.quit()
      } else throw new Error("unexpected settings transfer failure at stage " + root.stage)
    }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("settings transfer test timed out at stage " + root.stage) }
  }

  Component.onCompleted: {
    if (!transfer.request("export")) throw new Error("settings export did not start")
    if (transfer.activeMode !== "export") throw new Error("settings transfer mode did not activate")
    if (transfer.request("import")) throw new Error("concurrent settings transfer was not rejected")
  }
}
