import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int failures: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/event-failure-helper"))

  P2PEventJournal {
    id: journal
    helper: root.fixtureHelper
    events: [{kind:"existing",count:1}]
    onFailed: {
      root.failures += 1
      if (root.failures !== 1 || journal.busy || journal.queue.length !== 1 || journal.events[0].kind !== "existing")
        throw new Error("journal failure did not preserve queued work and existing events")
    }
    onEventsChanged: {
      if (events.length !== 0) return
      Qt.callLater(function() {
        if (root.failures !== 1 || journal.busy || journal.queue.length !== 0)
          throw new Error("journal queue did not recover after a failed command")
        console.log("P2P_QML_EVENT_JOURNAL_FAILURE_OK")
        Qt.quit()
      })
    }
  }

  Timer { interval: 3000; running: true; onTriggered: { throw new Error("journal failure recovery timed out") } }
  Component.onCompleted: { journal.load(); journal.clear() }
}
