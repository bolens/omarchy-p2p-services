pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string slowHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/catalog-slow-helper"))
  readonly property string healthyHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/catalog-helper"))

  P2PCatalogController {
    id: catalog
    helper: root.slowHelper
    timeoutMilliseconds: 100
    onFailed: function(exitCode) {
      if (root.stage !== 0 || exitCode !== -2 || catalog.running) throw new Error("catalog timeout was not normalized")
      root.stage = 1
    }
    onUpdated: function(entries) {
      if (root.stage !== 1 || entries.length !== 2 || entries[1].id !== "tailscale") throw new Error("queued catalog retry returned the wrong payload")
      if (catalog.running || catalog.pending || catalog.timedOut) throw new Error("successful catalog retry retained timeout state")
      root.stage = 2
      console.log("P2P_QML_CATALOG_TIMEOUT_RECOVERY_OK")
      Qt.quit()
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("catalog timeout recovery test timed out at stage " + root.stage) } }
  Component.onCompleted: {
    if (!catalog.request()) throw new Error("slow catalog request did not start")
    if (catalog.request() || !catalog.pending) throw new Error("catalog retry was not queued")
    catalog.helper = root.healthyHelper
  }
}
