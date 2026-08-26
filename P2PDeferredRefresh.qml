import QtQuick

QtObject {
  property var pending: null

  signal applyRequested(var services, bool fullScan)

  function receive(services, fullScan, defer) {
    if (defer === true) {
      pending = {services:Array.isArray(services) ? services : [],fullScan:fullScan === true}
      return false
    }
    pending = null
    applyRequested(Array.isArray(services) ? services : [], fullScan === true)
    return true
  }

  function flush() {
    if (!pending) return false
    var next = pending
    pending = null
    applyRequested(next.services, next.fullScan)
    return true
  }
}
