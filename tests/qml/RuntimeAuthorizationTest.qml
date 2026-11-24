import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property var phases: []
  readonly property string helper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/authorized-action-helper"))
  P2PActionRunner {
    id: runner
    onPhaseChanged: root.phases = root.phases.concat([phase])
    onActionFinished: function(entry, action, exitCode, detail) {
      if (entry.id !== "syncthing" || action !== "restart" || exitCode !== 0 || detail !== "") throw new Error("authorized action result was lost")
      if (runner.busy || runner.phase !== "") throw new Error("authorized action did not release pending state")
      if (root.phases.indexOf("authorization") < 0 || root.phases.indexOf("applying") < 0 || root.phases.indexOf("verifying") < 0) throw new Error("authorization phases did not reach the UI")
      if (runner.handleProgress('{"phase":"applying"}')) throw new Error("idle runner accepted stale progress")
      console.log("P2P_QML_AUTHORIZATION_OK")
      Qt.quit()
    }
  }
  Component.onCompleted: {
    if (!runner.request({id:"syncthing",authorizationRequired:true},"restart",[root.helper])) throw new Error("authorized request did not start")
    if (runner.phase !== "authorization" || runner.activeTimeoutMilliseconds !== runner.authorizationTimeoutMilliseconds) throw new Error("authorization did not get its own pending phase and deadline")
    if (runner.handleProgress('{"phase":"unknown"}') || runner.handleProgress('not JSON')) throw new Error("invalid progress changed pending state")
    if (runner.request({id:"syncthing",authorizationRequired:true},"stop",[root.helper])) throw new Error("overlapping authorized request was accepted")
  }
  Timer { interval: 3000; running: true; onTriggered: { throw new Error("authorized action timed out") } }
}
