import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/catalog-helper"))
  readonly property string malformedHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/catalog-malformed-helper"))

  P2PCatalogController {
    id: catalog
    helper: root.fixtureHelper
    onUpdated: function(entries) {
      if (root.stage !== 0 || entries.length !== 2 || entries[0].id !== "syncthing") throw new Error("catalog update payload failed")
      if (catalog.running || catalog.pending) throw new Error("catalog controller published an update before clearing active queue state")
      root.stage = 1
      catalog.helper = root.malformedHelper
      if (!catalog.request()) throw new Error("malformed catalog request did not start")
    }
    onFailed: function(exitCode) {
      if (root.stage === 1) {
        if (exitCode !== -1 || catalog.running) throw new Error("malformed catalog response was not rejected")
        root.stage = 2
        catalog.helper = "/usr/bin/false"
        if (!catalog.request()) throw new Error("failing catalog request did not start")
      } else if (root.stage === 2) {
        if (exitCode === 0 || catalog.running || catalog.pending) throw new Error("catalog failure cleanup retained busy or pending work")
        root.stage = 3
        console.log("P2P_QML_CATALOG_CONTROLLER_OK")
        Qt.quit()
      } else throw new Error("unexpected catalog failure at stage " + root.stage)
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("catalog test timed out at stage " + root.stage) } }

  Component.onCompleted: {
    if (!catalog.request()) throw new Error("catalog request did not start")
    if (catalog.request()) throw new Error("concurrent catalog request was not rejected")
  }
}
