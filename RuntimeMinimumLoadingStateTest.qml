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
    interval: 160
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
