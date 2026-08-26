import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int stage: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/event-helper"))

  P2PEventJournal {
    id: journal
    helper: root.fixtureHelper
    onEventsChanged: {
      if (root.stage === 0 && events.length === 1) {
        if (events[0].kind !== "unhealthy" || events[0].count !== 2) throw new Error("journal load payload failed")
        root.stage = 1; record("action-success", 1)
      } else if (root.stage === 1 && events.length === 2) {
        if (events[1].kind !== "action-success") throw new Error("journal append payload failed")
        root.stage = 2; clear()
      } else if (root.stage === 2 && events.length === 0) {
        root.stage = 3
        console.log("P2P_QML_EVENT_JOURNAL_OK")
        Qt.quit()
      }
    }
    onFailed: { throw new Error("journal command failed") }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("journal test timed out at stage " + root.stage) } }
  Component.onCompleted: journal.load()
}
