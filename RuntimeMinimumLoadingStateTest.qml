import Quickshell
import QtQuick

ShellRoot {
  id: root
  P2PMinimumLoadingState { id: state; minimumDuration: 120 }
  Component.onCompleted: state.start()
  Timer {
    interval: 40
    running: true
    onTriggered: {
      if (!state.visible || state.settled || state.minimumElapsed) throw new Error("minimum loading state did not start")
      state.finish()
      if (!state.visible || !state.settled) throw new Error("early completion did not retain presentation")
    }
  }
  Timer {
    interval: 80
    running: true
    onTriggered: {
      state.start()
      if (!state.visible || state.settled || state.minimumElapsed) throw new Error("restarted loading state did not reset its minimum window")
    }
  }
  Timer {
    interval: 160
    running: true
    onTriggered: {
      if (!state.visible || state.settled || state.minimumElapsed) throw new Error("loading restart retained the original deadline")
      state.finish()
      if (!state.visible || !state.settled) throw new Error("restarted loading state did not retain its remaining minimum window")
    }
  }
  Timer {
    interval: 240
    running: true
    onTriggered: {
      if (state.visible || !state.minimumElapsed) throw new Error("minimum loading state did not settle")
      state.start()
      state.presentationEnabled = false
      if (state.visible) throw new Error("disabled loading state remained visible")
      state.presentationEnabled = true
      if (!state.visible) throw new Error("re-enabled active loading state did not return")
      state.cancel()
      if (state.visible || !state.settled) throw new Error("cancelled loading state remained active")
      console.log("P2P_QML_MINIMUM_LOADING_STATE_OK")
      Qt.quit()
    }
  }
}
