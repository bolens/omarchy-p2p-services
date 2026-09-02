pragma ComponentBehavior: Bound
import QtQuick
import "Model.js" as Model

QtObject {
  property var pending: null

  signal applyRequested(var services, bool fullScan)

  function coalesce(services, fullScan) {
    var rows = Array.isArray(services) ? services : []
    if (pending && pending.fullScan === true && fullScan !== true)
      return {services:Model.mergeServiceStatus(pending.services, rows, false),fullScan:true}
    return {services:rows,fullScan:fullScan === true}
  }

  function receive(services, fullScan, defer) {
    var next = coalesce(services, fullScan)
    if (defer === true) {
      pending = next
      return false
    }
    pending = null
    applyRequested(next.services, next.fullScan)
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
