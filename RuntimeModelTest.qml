import Quickshell
import QtQuick
import "Model.js" as Model

ShellRoot {
  Component.onCompleted: {
    var service = {id:"syncthing",name:"Syncthing",category:"File sync",icon:"S",backend:"docker",unit:"syncthing.service",active:true,hasError:false}
    if (!Model.matchesSearch(service, "Home Sync", "docker")) throw new Error("backend search failed")
    if (!Model.matchesSearch(service, "Home Sync", "home")) throw new Error("label search failed")
    if (Model.matchesSearch(service, "Home Sync", "torrent")) throw new Error("negative search failed")
    if (!Model.matchesStatus(service, "running") || Model.matchesStatus(service, "issues")) throw new Error("status filter failed")
    var summary = Model.summary({active:true,connections:2,listeners:1,uptime:60}, true)
    if (summary !== "2 connected · 1 listening · up 1m · details filtered") throw new Error("privacy summary failed")
    if (Model.refreshBackoff(2) !== 4) throw new Error("failure backoff failed")
    var queued = Model.mergeRefreshRequest({forceCatalog:false,fullContainers:true,bypassCache:false}, true, false, true)
    if (!queued.forceCatalog || !queued.fullContainers || !queued.bypassCache) throw new Error("refresh coalescing failed")
    var rows = [{id:"slow",name:"Slow",connections:1},{id:"busy",name:"Busy",connections:8}]
    var sortContext = {mode:"connections",direction:"automatic",favoritesFirst:false,labels:{slow:"Slow",busy:"Busy"},sourceRanks:{slow:0,busy:1}}
    rows.sort(function(a, b) { return Model.compareServices(a, b, sortContext) })
    if (rows[0].id !== "busy") throw new Error("service sorting failed")
    var categories = Model.categorySummaries([service,{id:"idle",category:"File sync",icon:"S",active:false}], {"File sync":"F"}, true, false)
    if (categories.length !== 1 || categories[0].text !== "F 1/2") throw new Error("category bar summary failed")
    if (Model.groupLabel({backend:"systemd",unitScope:"user"}, "scope", false) !== "USER SERVICES") throw new Error("control scope grouping failed")
    if (Model.compareGroupLabels("NEEDS ATTENTION", "RUNNING", "status", "automatic") >= 0) throw new Error("semantic group ordering failed")
    if (!Model.organizationChanged({serviceSortMode:"name"}) || Model.organizationChanged({popupWidth:700})) throw new Error("organization invalidation failed")
    if (Model.barPresentationText([service], "category-active-total", "W", {"File sync":"F"}, false) !== "F 1/1") throw new Error("category bar presentation failed")
    if (Model.loadingFrame("spinner", ">", 1) !== "⠙") throw new Error("bar spinner frame failed")
    if (Model.loadingFrame("glyph", " # ", 9) !== "#") throw new Error("bar custom loading glyph failed")
    var indicators = Model.compactIndicators({connections:2,listeners:1,processCount:1,hasWeb:true,configExists:false})
    if (indicators.length !== 4 || indicators[0].value !== "2" || indicators[0].action !== "details" || indicators[3].action !== "console") throw new Error("compact service indicators failed")
    var saved = Model.savedViewSelection({search:"sync",filter:"running",backend:"docker",sortMode:"name",groupMode:"category"})
    if (saved.search !== "sync" || saved.filter !== "running" || saved.backend !== "docker" || saved.patch.serviceSortMode !== "name" || saved.patch.serviceGroupMode !== "category") throw new Error("saved view selection failed")
    if (Model.serviceNotificationPolicy({syncthing:"failures"}, "syncthing") !== "failures" || !Model.shouldNotifyService("failures", 1, false)) throw new Error("service notification policy failed")
    var custom = Model.parseCustomServices('[{"id":"mesh"}]')
    if (!custom.valid || custom.services.length !== 1 || Model.parseCustomServices("{}").valid) throw new Error("custom service parsing failed")
    var notification = Model.actionNotification("Syncthing", "restart", 1, "details\nlast reason")
    if (notification.title !== "P2P service action failed" || notification.body.indexOf("last reason") >= 0) throw new Error("action notification leaked raw stderr")
    var watcher = Model.parseWatcherEvent('{"type":"watch-event","version":1,"kind":"changed"}', 1000)
    if (!watcher.accepted || !watcher.changed || Model.watcherExitState(true, 4000).nextRetryMilliseconds !== 8000) throw new Error("watcher lifecycle policy failed")
    console.log("P2P_QML_RUNTIME_OK")
    Qt.quit()
  }
}
