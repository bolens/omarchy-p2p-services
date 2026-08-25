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
    return Model.sortServices(entries, {mode:mode,direction:"automatic",favoritesFirst:false,labels:{},sourceRanks:{z:0,a:1}}, organization.stableOrder, false)
  }

  property int stopEvents: 0
  P2POrganizationState { id: organization; onStabilityStopRequested: root.stopEvents++ }

  Component.onCompleted: {
    if (ordered[0].id !== "z") throw new Error("initial custom order failed")
    if (!organization.capture(["z","a"], true)) throw new Error("organization capture failed")
    mode = "name"
    if (!organization.invalidate({serviceSortMode:"name"})) throw new Error("organization event rejected")
    if (organization.stableOrder.length !== 0 || stopEvents !== 1) throw new Error("organization event did not clear stabilization")
    if (organization.invalidate({popupWidth:700})) throw new Error("presentation event changed organization")
    Qt.callLater(function() {
      if (ordered[0].id !== "a") throw new Error("event-driven organization failed")
      console.log("P2P_QML_ORGANIZATION_OK")
      Qt.quit()
    })
  }
}
