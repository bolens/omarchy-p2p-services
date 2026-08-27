import Quickshell
import QtQuick
import "Model.js" as Model

ShellRoot {
  id: root
  property string mode: "custom"
  property var entries: [
    {id:"z",name:"Zulu",category:"Overlay network"},
    {id:"a",name:"Alpha",category:"File sync"}
  ]
  readonly property var ordered: {
    var eventRevision = organization.revision
    return Model.sortServices(entries, {mode:mode,direction:"automatic",favoritesFirst:false,labels:{},sourceRanks:{z:0,a:1}}, organization.stableOrder, organization.stableOrder.length > 0)
  }

  property int stopEvents: 0
  P2POrganizationState { id: organization; onStabilityStopRequested: root.stopEvents++ }

  Component.onCompleted: Qt.callLater(function() {
    if (ordered[0].id !== "z") throw new Error("initial custom order failed")
    var captured = ["z","a"]
    if (!organization.capture(captured, true)) throw new Error("organization capture failed")
    captured.reverse()
    if (organization.stableOrder[0] !== "z") throw new Error("organization capture retained a mutable source array")
    entries = entries.concat([{id:"m",name:"Mesh",category:"Overlay network"}])
    if (ordered.length !== 3 || ordered[0].id !== "z" || ordered[1].id !== "a" || ordered[2].id !== "m")
      throw new Error("stable organization dropped or reordered a newly discovered service: " + JSON.stringify(ordered.map(function(entry) { return entry.id })))
    mode = "name"
    if (!organization.invalidate({serviceSortMode:"name"})) throw new Error("organization event rejected")
    if (organization.stableOrder.length !== 0 || stopEvents !== 1) throw new Error("organization event did not clear stabilization")
    if (organization.invalidate({popupWidth:700})) throw new Error("presentation event changed organization")
    Qt.callLater(function() {
      if (ordered.length !== 3 || ordered[0].id !== "a" || ordered[1].id !== "m" || ordered[2].id !== "z")
        throw new Error("event-driven organization failed after membership changed")
      console.log("P2P_QML_ORGANIZATION_OK")
      Qt.quit()
    })
  })
}
