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
    onFailed: { throw new Error("coalesced journal load failed") }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: { throw new Error("journal load coalescing timed out") }
  }

  Component.onCompleted: {
    journal.helper = "   "
    if (journal.load() || journal.record("unhealthy", 1) || journal.clear()) throw new Error("blank journal helper was accepted")
    if (journal.busy || journal.queue.length !== 0) throw new Error("blank journal helper changed queue state")
    journal.helper = root.fixtureHelper
    if (journal.record("   ", 1) || journal.busy || journal.queue.length !== 0) throw new Error("blank journal event kind was queued")
    journal.load()
    journal.load()
    journal.load()
    journal.load()
    if (!journal.busy || journal.queue.length !== 0)
      throw new Error("duplicate journal loads were queued")
    journal.process.exited.connect(function() {
      root.completions += 1
      Qt.callLater(function() {
        if (root.completions !== 1 || journal.busy || journal.queue.length !== 0 || journal.events.length !== 1)
          throw new Error("coalesced journal load did not settle once")
        console.log("P2P_QML_EVENT_JOURNAL_COALESCING_OK")
        Qt.quit()
      })
    })
  }
}
