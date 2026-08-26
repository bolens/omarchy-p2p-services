import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/transfer-helper"))

  P2PSettingsTransferController {
    id: transfer
    helper: root.fixtureHelper
    onSucceeded: function(mode, payload) {
      if (root.stage !== 1 || mode !== "export" || payload !== "export-ok") throw new Error("transfer after undo probe returned the wrong result")
      if (transfer.running || transfer.activeMode !== "" || !transfer.undoAvailable) throw new Error("transfer availability was lost after the probe")
      root.stage = 2
      console.log("P2P_QML_SETTINGS_TRANSFER_AVAILABILITY_OK")
      Qt.quit()
    }
    onFailed: function(mode, exitCode, _detail) { throw new Error("settings transfer availability flow failed: " + mode + "/" + exitCode) }
  }

  Timer {
    interval: 20
    running: true
    repeat: true
    onTriggered: {
      if (root.stage !== 0 || transfer.running) return
      if (!transfer.undoAvailable || transfer.activeMode !== "") throw new Error("undo availability probe did not clear completed state")
      root.stage = 1
      if (!transfer.request("export")) throw new Error("transfer remained blocked after undo availability probe")
    }
  }
  Timer { interval: 3000; running: true; onTriggered: { throw new Error("settings transfer availability test timed out at stage " + root.stage) } }

  Component.onCompleted: {
    if (!transfer.refreshUndoAvailability()) throw new Error("undo availability probe did not start")
    if (transfer.request("export") || transfer.refreshUndoAvailability()) throw new Error("undo availability probe accepted concurrent work")
  }
}
