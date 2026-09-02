pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int completions: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/event-helper"))

  P2PEventJournal {
    id: journal
    helper: root.fixtureHelper
    events: [{kind:"existing",count:1}]
    onFailed: { throw new Error("coalesced journal clear failed") }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("journal clear coalescing timed out") } }

  Component.onCompleted: {
    if (!journal.clear()) throw new Error("initial journal clear did not start")
    if (journal.clear() || journal.clear()) throw new Error("duplicate journal clear was accepted")
    if (!journal.busy || journal.queue.length !== 0) throw new Error("duplicate journal clear changed queue state")
    journal.process.exited.connect(function() {
      root.completions += 1
      Qt.callLater(function() {
        if (root.completions !== 1 || journal.busy || journal.queue.length !== 0 || journal.events.length !== 0)
          throw new Error("coalesced journal clear did not settle once")
        console.log("P2P_QML_EVENT_JOURNAL_CLEAR_COALESCING_OK")
        Qt.quit()
      })
    })
  }
}
