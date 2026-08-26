import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/action-helper"))
  readonly property string failingHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/action-failing-helper"))

  P2PActionRunner {
    id: runner
    onActionFinished: function(entry, action, exitCode, detail) {
      if (root.stage === 0) {
        if (entry.id !== "syncthing" || action !== "start" || exitCode !== 0) throw new Error("service action success payload failed")
        if (runner.running) throw new Error("service action runner remained busy before completion")
        root.stage = 1
        if (!runner.request({id:"tailscale"}, "stop", [root.failingHelper])) throw new Error("failing service action did not start")
      } else {
        if (root.stage !== 1 || entry.id !== "tailscale" || action !== "stop" || exitCode === 0) throw new Error("service action failure payload failed")
        if (detail.length !== 512 || detail.charAt(0) !== "x" || detail.charAt(511) !== "x") throw new Error("service action stderr was not trimmed and bounded")
        if (runner.running) throw new Error("service action runner remained busy after failure")
        root.stage = 2
        console.log("P2P_QML_ACTION_RUNNER_OK")
        Qt.quit()
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("service action runner test timed out at stage " + root.stage) }
  }

  Component.onCompleted: {
    if (!runner.request({id:"syncthing"}, "start", [root.fixtureHelper])) throw new Error("service action did not start")
    if (runner.request({id:"tailscale"}, "stop", ["/usr/bin/false"])) throw new Error("concurrent service action was not rejected")
  }
}
