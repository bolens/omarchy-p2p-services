import QtQuick
import "Model.js" as Model

QtObject {
  property var stableOrder: []
  property int revision: 0

  signal stabilityStopRequested()

  function capture(order, enabled) {
    if (enabled !== true) return false
    stableOrder = (order || []).slice()
    return true
  }

  function invalidate(patch) {
    if (!Model.organizationChanged(patch)) return false
    stableOrder = []
    revision++
    stabilityStopRequested()
    return true
  }

  function expire() { stableOrder = [] }
}
