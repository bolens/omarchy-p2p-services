import Quickshell
import QtQuick

ShellRoot {
  P2PEventJournal { id: journal; helper: "/unused/helper"; busy: true }

  Component.onCompleted: {
    Qt.callLater(function() {
      for (var index = 0; index < 150; index++)
        if (!journal.record("event-" + index, 1)) throw new Error("bounded journal queue rejected normal work")
      if (journal.queue.length !== 100
          || journal.queue[0][2] !== "event-50"
          || journal.queue[99][2] !== "event-149")
        throw new Error("journal queue did not retain the newest bounded work")
      if (journal.record("x".repeat(262144), 1)) throw new Error("oversized journal command was accepted")
      if (journal.queue.length !== 100) throw new Error("oversized journal command discarded queued work")
      if (!journal.clear() || journal.queue.length !== 1 || journal.queue[0][1] !== "events-clear")
        throw new Error("journal clear did not supersede obsolete queued commands")
      console.log("P2P_QML_EVENT_JOURNAL_QUEUE_BOUNDS_OK")
      Qt.quit()
    })
  }
}
