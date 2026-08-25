import QtQuick

QtObject {
  id: state
  property int minimumDuration: 400
  property bool presentationEnabled: true
  property bool visible: false
  property bool settled: true
  property bool minimumElapsed: true

  function start() {
    minimumTimer.stop()
    settled = false
    minimumElapsed = false
    visible = presentationEnabled
    minimumTimer.start()
  }
  function finish() {
    settled = true
    if (minimumElapsed) visible = false
  }
  function cancel() {
    minimumTimer.stop()
    settled = true
    minimumElapsed = true
    visible = false
  }

  onPresentationEnabledChanged: {
    if (!presentationEnabled) visible = false
    else if (!settled || !minimumElapsed) visible = true
  }

  property Timer minimumTimer: Timer {
    interval: Math.max(0, state.minimumDuration)
    onTriggered: {
      state.minimumElapsed = true
      if (state.settled) state.visible = false
    }
  }
}
