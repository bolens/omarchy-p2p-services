const fs = require("fs"), vm = require("vm"), assert = require("assert");
const source = fs.readFileSync(require("path").join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "");
const context = {}; vm.createContext(context); vm.runInContext(source, context);
const manifest = JSON.parse(fs.readFileSync(require("path").join(__dirname, "..", "manifest.json"), "utf8"));
assert.deepEqual(JSON.parse(JSON.stringify(context.settingsDefaults())), manifest.barWidget.defaults);
assert.equal(context.formatDuration(3660), "1h 1m");
assert.equal(context.summary({active:false}, true), "Stopped");
assert.equal(context.summary({active:true,connections:2,listeners:1,uptime:60}, true), "2 connected · 1 listening · up 1m · details filtered");
assert.deepEqual(JSON.parse(JSON.stringify(context.compactIndicators({connections:2,listeners:1,processCount:3,hasWeb:true,configExists:true}))), [
  {icon:"󰌷",value:"2",tooltip:"2 peer connections · Show details",action:"details"},
  {icon:"󰖟",value:"1",tooltip:"1 listening socket · Show details",action:"details"},
  {icon:"󰆍",value:"3",tooltip:"3 running processes · Show details",action:"details"},
  {icon:"󰖟",value:"",tooltip:"Open web console",action:"console"},
  {icon:"󰒓",value:"",tooltip:"Open configuration",action:"config"}
]);
assert.deepEqual(JSON.parse(JSON.stringify(context.compactIndicators({connections:0,listeners:0,processCount:0}))), []);
assert.deepEqual(JSON.parse(JSON.stringify(context.compactIndicators({configExists:true,controllable:false}))), [
  {icon:"󰒓",value:"",tooltip:"Configuration detected · Observation only",action:"config",enabled:false}
]);
assert.equal(context.formatRate(1536), "1.5 KiB/s");
assert.equal(context.formatRate(1500000), "1.4 MiB/s");
assert.deepEqual(JSON.parse(JSON.stringify(context.loadingFrames("dots", ">"))), [".  ", ".. ", "..."]);
assert.equal(context.loadingFrame("spinner", ">", 1), "⠙");
assert.equal(context.loadingFrame("glyph", " # ", 99), "#");
assert.equal(context.loadingFrame("glyph", "   ", 0), ">");
const searchEntry = {name:"Syncthing",id:"syncthing",backend:"docker",unit:"syncthing.service"};
assert.equal(context.matchesSearch(searchEntry, "Home Sync", "home"), true);
assert.equal(context.matchesSearch(searchEntry, "Home Sync", "DOCKER"), true);
assert.equal(context.matchesSearch(searchEntry, "Home Sync", "thing"), true);
assert.equal(context.matchesSearch(searchEntry, "Home Sync", "torrent"), false);
assert.equal(context.matchesSearch(searchEntry, "Home Sync", "  "), true);
assert.equal(context.matchesStatus({active:true,hasError:false}, "running"), true);
assert.equal(context.matchesStatus({active:false,hasError:false}, "running"), false);
assert.equal(context.matchesStatus({active:false,hasError:false}, "stopped"), true);
assert.equal(context.matchesStatus({active:true,hasError:true}, "issues"), true);
assert.equal(context.matchesStatus({active:true,hasError:false}, "issues"), false);
assert.equal(context.matchesStatus({active:false,hasError:false}, "all"), true);
assert.equal(context.matchesBackend({backend:"docker"}, "docker"), true);
assert.equal(context.matchesBackend({backend:"systemd"}, "docker"), false);
assert.equal(context.matchesBackend({backend:"systemd"}, ""), true);
assert.equal(context.safeHttpUrl("https://node.example.test:8443/ui"), "https://node.example.test:8443/ui");
assert.equal(context.safeHttpUrl("http://user:secret\.test"), "");
assert.equal(context.safeHttpUrl("http://ok.example\nfile:///tmp/x"), "");
assert.equal(context.refreshBackoff(0), 1);
assert.equal(context.refreshBackoff(1), 2);
assert.equal(context.refreshBackoff(2), 4);
assert.equal(context.refreshBackoff(20), 4);
assert.deepEqual(
  JSON.parse(JSON.stringify(context.mergeRefreshRequest({forceCatalog:false,fullContainers:true,bypassCache:false}, true, false, true))),
  {forceCatalog:true,fullContainers:true,bypassCache:true}
);
const sortRows = [
  {id:"slow",name:"Slow",active:true,hasError:false,connections:1,uptime:900,backend:"systemd"},
  {id:"busy",name:"Busy",active:true,hasError:false,connections:8,uptime:120,backend:"docker"},
  {id:"down",name:"Down",active:false,hasError:false,connections:0,uptime:0,backend:"systemd"}
];
const sortContext = {
  mode:"connections", direction:"automatic", favoritesFirst:true,
  favorites:{slow:true}, labels:{slow:"Slow",busy:"Busy",down:"Down"},
  orderRanks:{}, sourceRanks:{slow:0,busy:1,down:2}, trafficRates:{}
};
assert.deepEqual(sortRows.slice().sort((a,b) => context.compareServices(a,b,sortContext)).map(row => row.id), ["slow","busy","down"]);
sortContext.favoritesFirst = false;
assert.deepEqual(sortRows.slice().sort((a,b) => context.compareServices(a,b,sortContext)).map(row => row.id), ["busy","slow","down"]);
sortContext.direction = "ascending";
assert.deepEqual(sortRows.slice().sort((a,b) => context.compareServices(a,b,sortContext)).map(row => row.id), ["down","slow","busy"]);
sortContext.mode = "uptime"; sortContext.direction = "automatic";
assert.deepEqual(sortRows.slice().sort((a,b) => context.compareServices(a,b,sortContext)).map(row => row.id), ["slow","busy","down"]);
sortContext.mode = "connections"; sortContext.direction = "automatic";
assert.deepEqual(context.sortServices(sortRows, sortContext, ["down","slow","busy"], true).map(row => row.id), ["down","slow","busy"]);
const frozenGrouped = [{id:"a1",category:"A"},{id:"b1",category:"B"},{id:"a2",category:"A"}];
assert.deepEqual(context.sortServices(frozenGrouped, {groupMode:"category",groupDirection:"automatic",favoritesFirst:false}, ["a1","b1","a2"], true).map(row => row.id), ["a1","a2","b1"]);
assert.equal(context.groupLabel(sortRows[1], "backend", false), "DOCKER");
assert.equal(context.groupLabel(sortRows[2], "status", false), "STOPPED");
assert.equal(context.groupLabel({category:"Overlay network"}, "category", false), "OVERLAY NETWORK");
assert.equal(context.groupLabel({backend:"systemd",unitScope:"user"}, "scope", false), "USER SERVICES");
assert.equal(context.groupLabel({backend:"docker",runtimes:["docker"]}, "scope", false), "CONTAINERS");
assert.equal(context.compareGroupLabels("RUNNING", "STOPPED", "status", "automatic") < 0, true);
assert.equal(context.compareGroupLabels("NEEDS ATTENTION", "RUNNING", "status", "automatic") < 0, true);
assert.equal(context.compareGroupLabels("ALPHA", "BETA", "category", "descending") > 0, true);
assert.equal(context.compareGroupLabels("ALPHA", "BETA", "category", "ascending") < 0, true);
assert.equal(context.compareGroupLabels("CONTAINERS", "PROCESSES", "scope", "automatic") < 0, true);
assert.equal(context.compareGroupLabels("FAVORITES", "OTHER SERVICES", "favorite", "automatic") < 0, true);
const categorySort = [{id:"z",name:"Z",category:"Overlay network"},{id:"a",name:"A",category:"File sync"}];
assert.deepEqual(categorySort.sort((a,b) => context.compareServices(a,b,{mode:"category",direction:"automatic",favoritesFirst:false,labels:{}})).map(row => row.id), ["a","z"]);
assert.equal(context.matchesSearch({category:"Overlay network"}, "Tailscale", "overlay"), true);
const categoryRows = context.categorySummaries([
  {category:"Overlay network",icon:"O",active:true},
  {category:"Overlay network",icon:"O",active:false},
  {category:"File sync",icon:"S",active:true}
], {"Overlay network":"M"}, true, false);
assert.deepEqual(JSON.parse(JSON.stringify(categoryRows)), [
  {category:"File sync",icon:"S",active:1,total:1,text:"S 1/1"},
  {category:"Overlay network",icon:"M",active:1,total:2,text:"M 1/2"}
]);
assert.deepEqual(JSON.parse(JSON.stringify(context.categorySummaries([
  {category:"Idle",icon:"I",active:false}
], {}, false, true))), []);
const barEntries = [
  {category:"File sync",icon:"S",active:true,hasError:false},
  {category:"Overlay network",icon:"O",active:false,hasError:false}
];
assert.equal(context.barPresentationText(barEntries, "category-active", "W", {"File sync":"F"}, false), "F 1  O 0");
assert.equal(context.barPresentationText(barEntries, "category-active-total", "W", {}, false), "S 1/1  O 0/1");
assert.equal(context.barPresentationText(barEntries, "category-active", "W", {}, true), "S 1");
assert.equal(context.barPresentationText([], "category-active", "W", {}, true), "W");
assert.equal(context.barPresentationText(barEntries, "active-total", "W", {}, false), "W 1/2");
assert.deepEqual(JSON.parse(JSON.stringify(context.categoryIconMap({Existing:"E"}, "File sync", " S "))), {Existing:"E","File sync":"S"});
assert.deepEqual(JSON.parse(JSON.stringify(context.categoryIconMap({Existing:"E","File sync":"S"}, "File sync", "  "))), {Existing:"E"});
assert.equal(context.groupCountText([{active:true},{active:false}], "active-total"), "1/2 active");
assert.equal(context.groupCountText([{active:true},{active:false}], "active"), "1 active");
assert.equal(context.groupCountText([{active:true},{active:false}], "total"), "2");
assert.equal(context.groupIcon({category:"Overlay network",icon:"O"}, "category", false, {"Overlay network":"M"}), "M");
assert.equal(context.groupIcon({backend:"systemd",unitScope:"system"}, "scope", false, {}), "󰒓");
assert.equal(context.groupIcon({active:true,hasError:true}, "status", false, {}), "󰅚");
assert.equal(context.groupIcon({active:true,hasError:false}, "status", false, {}), "󰐊");
assert.equal(context.groupIcon({active:false,hasError:false}, "status", false, {}), "󰓛");
assert.equal(context.groupIcon({}, "favorite", true, {}), "󰓎");
assert.equal(context.groupIcon({backend:"process"}, "scope", false, {}), "󰆍");
assert.equal(context.organizationChanged({serviceSortMode:"name"}), true);
assert.equal(context.organizationChanged({serviceGroupDirection:"descending"}), true);
assert.equal(context.organizationChanged({favoriteServices:["syncthing"]}), true);
assert.equal(context.organizationChanged({popupWidth:700}), false);
assert.deepEqual(JSON.parse(JSON.stringify(context.savedViewPatch({
  sortMode:"traffic",sortDirection:"descending",groupMode:"category",
  groupDirection:"ascending",favoritesFirst:false
}))), {
  serviceSortMode:"traffic",serviceSortDirection:"descending",
  serviceGroupMode:"category",serviceGroupDirection:"ascending",favoritesFirst:false
});
assert.deepEqual(JSON.parse(JSON.stringify(context.savedViewPatch({}))), {
  serviceSortMode:"custom",serviceSortDirection:"automatic",
  serviceGroupMode:"none",serviceGroupDirection:"automatic",favoritesFirst:true
});
assert.deepEqual(JSON.parse(JSON.stringify(context.savedViewSelection({
  search:"sync",filter:"running",backend:"docker",sortMode:"name",groupMode:"scope"
}))), {
  search:"sync",filter:"running",backend:"docker",patch:{serviceSortMode:"name",serviceSortDirection:"automatic",serviceGroupMode:"scope",serviceGroupDirection:"automatic",favoritesFirst:true}
});
assert.deepEqual(JSON.parse(JSON.stringify(context.smoothTrafficRate({rx:100,tx:50},{rx:300,tx:0},0.25,80))), {rx:150,tx:37.5,active:true});
assert.deepEqual(JSON.parse(JSON.stringify(context.serviceTransitions(
  [{id:"a",active:true,hasError:false,restartCount:1},{id:"b",active:false,hasError:true,restartCount:0}],
  [{id:"a",active:false,hasError:false,restartCount:1},{id:"b",active:true,hasError:false,restartCount:4}], 3
))), [{id:"a",kind:"stopped"},{id:"b",kind:"recovered"},{id:"b",kind:"restarts",count:4}]);
assert.equal(context.ensureVisibleContentY(0, 300, 500, 60, 1000), 260);
assert.equal(context.ensureVisibleContentY(300, 300, 120, 60, 1000), 120);
assert.equal(context.ensureVisibleContentY(200, 300, 250, 60, 1000), 200);
assert.equal(context.ensureVisibleContentY(600, 300, 980, 80, 1000), 700);
assert.equal(context.nextSelectionIndex(5, -1, 1), 0);
assert.equal(context.nextSelectionIndex(5, -1, -1), 4);
assert.equal(context.nextSelectionIndex(5, 2, 1), 3);
assert.equal(context.nextSelectionIndex(5, 0, -1), 0);
assert.equal(context.nextSelectionIndex(5, 4, 1), 4);
assert.equal(context.serviceNotificationPolicy({syncthing:"failures"}, "syncthing"), "failures");
assert.equal(context.serviceNotificationPolicy({syncthing:"unexpected"}, "syncthing"), "inherit");
assert.equal(context.serviceNotificationPolicy({}, "syncthing"), "inherit");
assert.equal(context.shouldNotifyService("always", 0, false), true);
assert.equal(context.shouldNotifyService("failures", 0, true), false);
assert.equal(context.shouldNotifyService("failures", 7, false), true);
assert.equal(context.shouldNotifyService("silent", 7, true), false);
assert.equal(context.shouldNotifyService("inherit", 0, false), false);
assert.equal(context.shouldNotifyService("inherit", 0, true), true);
assert.deepEqual(JSON.parse(JSON.stringify(context.serviceMapPatch(
  {serviceLabels:{syncthing:"Home Sync",tailscale:"Mesh"}}, "serviceLabels", "syncthing", "", true
))), {serviceLabels:{tailscale:"Mesh"}});
assert.deepEqual(JSON.parse(JSON.stringify(context.serviceMapPatch(
  {serviceShowStopped:{syncthing:true}}, "serviceShowStopped", "syncthing", false, false
))), {serviceShowStopped:{syncthing:false}});
assert.deepEqual(JSON.parse(JSON.stringify(context.resetServicePatch({
  serviceLabels:{syncthing:"Home Sync",tailscale:"Mesh"},
  serviceIcons:{syncthing:"S"},serviceShowStopped:{syncthing:false},
  serviceConsoleUrls:{syncthing:"https://sync.example.test"},
  serviceNotificationPolicies:{syncthing:"silent",tailscale:"always"},
  favoriteServices:["syncthing","tailscale"]
}, "syncthing"))), {
  serviceLabels:{tailscale:"Mesh"},serviceIcons:{},serviceShowStopped:{},
  serviceConsoleUrls:{},serviceNotificationPolicies:{tailscale:"always"},
  favoriteServices:["tailscale"]
});
const globalReset = JSON.parse(JSON.stringify(context.globalSettingsResetPatch({
  popupWidth:777,serviceLabels:{syncthing:"Home Sync"},serviceIcons:{syncthing:"S"},
  serviceShowStopped:{syncthing:false},serviceConsoleUrls:{syncthing:"https://sync.example.test"},
  serviceNotificationPolicies:{syncthing:"silent"},favoriteServices:["syncthing"],
  serviceOrder:["syncthing","tailscale"]
})));
assert.equal(globalReset.popupWidth, 600);
assert.deepEqual(globalReset.serviceLabels, {syncthing:"Home Sync"});
assert.deepEqual(globalReset.serviceIcons, {syncthing:"S"});
assert.deepEqual(globalReset.serviceShowStopped, {syncthing:false});
assert.deepEqual(globalReset.serviceConsoleUrls, {syncthing:"https://sync.example.test"});
assert.deepEqual(globalReset.serviceNotificationPolicies, {syncthing:"silent"});
assert.deepEqual(globalReset.favoriteServices, ["syncthing"]);
assert.deepEqual(globalReset.serviceOrder, ["syncthing","tailscale"]);
assert.deepEqual(JSON.parse(JSON.stringify(context.parseCustomServices(' [{"id":"mesh"}] '))), {valid:true,services:[{id:"mesh"}]});
assert.deepEqual(JSON.parse(JSON.stringify(context.parseCustomServices("  "))), {valid:true,services:[]});
assert.deepEqual(JSON.parse(JSON.stringify(context.parseCustomServices('{"id":"mesh"}'))), {valid:false,services:[]});
assert.deepEqual(JSON.parse(JSON.stringify(context.parseCustomServices("not json"))), {valid:false,services:[]});
assert.deepEqual(JSON.parse(JSON.stringify(context.actionNotification("Syncthing", "start", 0, ""))), {
  title:"P2P service updated",body:"Syncthing start completed"
});
assert.deepEqual(JSON.parse(JSON.stringify(context.actionNotification("Tailscale", "stop", 126, ""))), {
  title:"P2P service action cancelled",body:"Stop Tailscale was cancelled"
});
assert.deepEqual(JSON.parse(JSON.stringify(context.actionNotification("Headscale", "restart", 1, "first\nlast reason\n"))), {
  title:"P2P service action failed",body:"Restart Headscale failed. Check the service and system logs for details"
});
const privateFailure = context.actionNotification("NetBird", "start", 1, "/home/alice/token at 10.0.0.8");
assert.equal(privateFailure.body.includes("alice"), false);
const previousStatus = [
  {id:"docker-service",backend:"docker",active:true,hasError:true,health:"unhealthy",pids:[7],processCount:1,connections:2,listeners:1,endpoints:["x"],uptime:30,rxBytes:10,txBytes:20,trafficAvailable:true},
  {id:"system-service",backend:"systemd",active:true},
  {id:"kept",backend:"systemd",active:true,name:"Old"}
];
const fastMerged = JSON.parse(JSON.stringify(context.mergeServiceStatus(previousStatus, [
  {id:"kept",backend:"systemd",active:true,name:"New"},{id:"new",backend:"process",active:true}
], false)));
assert.deepEqual(fastMerged.map(entry => entry.id), ["docker-service","kept","new"]);
assert.equal(fastMerged[0].active, false);
assert.equal(fastMerged[0].health, "stopped");
assert.deepEqual(fastMerged[0].pids, []);
assert.equal(fastMerged[0].trafficAvailable, false);
assert.equal(fastMerged[1].name, "New");
assert.deepEqual(JSON.parse(JSON.stringify(context.mergeServiceStatus(previousStatus, [{id:"only"}], true))), [{id:"only"}]);
assert.deepEqual(JSON.parse(JSON.stringify(context.refreshFailureState(2, " helper failed "))), {
  failures:3,error:"Unable to refresh P2P service status; showing the last successful result. helper failed"
});
assert.equal(context.refreshHealthText({lastSuccessfulAt:0}, 5000), "Waiting for the first successful refresh");
assert.equal(context.refreshHealthText({lastSuccessfulAt:1000,lastScanKind:"Full reconciliation",durationMs:42,staleSeconds:3,diagnostics:2,failures:1}, 5000),
  "Full reconciliation · 42 ms · updated 4s ago · data may be stale · 2 partial probe warnings · 1 consecutive failure");
let cooldown = JSON.parse(JSON.stringify(context.transitionCooldown({}, "sync", "stopped", 10000, 30)));
assert.equal(cooldown.allowed, true);
assert.equal(cooldown.timestamps["sync:stopped"], 10000);
cooldown = JSON.parse(JSON.stringify(context.transitionCooldown(cooldown.timestamps, "sync", "stopped", 20000, 30)));
assert.equal(cooldown.allowed, false);
assert.equal(cooldown.timestamps["sync:stopped"], 10000);
assert.equal(context.transitionCooldown(cooldown.timestamps, "sync", "stopped", 20000, 0).allowed, true);
assert.deepEqual(JSON.parse(JSON.stringify(context.parseWatcherEvent('{"type":"watch-event","version":1,"kind":"changed","healthy":true,"code":"ok"}', 1234))), {
  accepted:true,changed:true,heartbeatAt:1234,health:"healthy",code:"ok",retryMilliseconds:1000
});
assert.equal(context.parseWatcherEvent('{"type":"other","version":1}', 1234).accepted, false);
assert.equal(context.parseWatcherEvent("invalid", 1234).accepted, false);
assert.deepEqual(JSON.parse(JSON.stringify(context.watcherExitState(true, 4000))), {
  retry:true,delay:4000,nextRetryMilliseconds:8000,health:"degraded",code:"watcher_exited"
});
assert.equal(context.watcherExitState(false, 4000).retry, false);
assert.equal(context.watcherExitState(true, 60000).nextRetryMilliseconds, 60000);
assert.equal(context.watcherHeartbeatState(1000, 45000, 45000).stale, false);
assert.deepEqual(JSON.parse(JSON.stringify(context.watcherHeartbeatState(1000, 46001, 45000))), {stale:true,health:"degraded",code:"heartbeat_stale"});
assert.equal(context.watcherHeartbeatState(0, 1000, 45000).stale, true);
assert.equal(context.monitoringHealthSeverity("healthy", "healthy", "ok"), "neutral");
assert.equal(context.monitoringHealthSeverity("disabled", "healthy", "ok"), "neutral");
assert.equal(context.monitoringHealthSeverity("polling", "starting", "waiting"), "neutral");
assert.equal(context.monitoringHealthSeverity("degraded", "healthy", "ok"), "urgent");
assert.equal(context.monitoringHealthSeverity("healthy", "starting", "restarting"), "urgent");
assert.equal(context.monitoringHealthSeverity("healthy", "degraded", "handshake_timeout"), "urgent");
assert.deepEqual(JSON.parse(JSON.stringify(context.parseTransferredSettings('{"popupWidth":700}', "plugin-id", "import"))), {
  valid:true,settings:{popupWidth:700}
});
assert.deepEqual(JSON.parse(JSON.stringify(context.parseTransferredSettings('{"popupWidth":700}', "plugin-id", "undo"))), {
  valid:true,settings:{popupWidth:700,id:"plugin-id"}
});
assert.equal(context.parseTransferredSettings("[]", "plugin-id", "import").valid, false);
assert.equal(context.parseTransferredSettings("invalid", "plugin-id", "undo").valid, false);
assert.deepEqual(JSON.parse(JSON.stringify(context.parseCatalog('[{"id":"syncthing"}]'))), [{id:"syncthing"}]);
assert.equal(context.parseCatalog("{}"), null);
assert.equal(context.parseCatalog("invalid"), null);
assert.deepEqual(JSON.parse(JSON.stringify(context.consoleUrlUpdate(" https://node.example.test/ui "))), {valid:true,url:"https://node.example.test/ui"});
assert.deepEqual(JSON.parse(JSON.stringify(context.consoleUrlUpdate("  "))), {valid:true,url:""});
assert.deepEqual(JSON.parse(JSON.stringify(context.consoleUrlUpdate("file:///tmp/ui"))), {valid:false,url:""});

const indexes = JSON.parse(JSON.stringify(context.serviceIndexes([
  {id:"a",active:true,hasError:false,category:"Sync"},
  {id:"b",active:true,hasError:true,category:"Sync"},
  {id:"c",active:false,hasError:false,category:"Storage"},
], ["c"], "category")));
assert.equal(indexes.active, 2);
assert.equal(indexes.errors, 1);
assert.equal(indexes.total, 3);
assert.equal(indexes.byId.b.id, "b");
assert.equal(indexes.groupById.b, "SYNC");
assert.equal(indexes.groupById.c, "STORAGE");
assert.equal(indexes.favorites.c, true);
assert.deepEqual(indexes.groups.SYNC, {active:2,total:2});
assert.equal(context.indexedGroupCountText(indexes, "SYNC", "active-total"), "2/2 active");
console.log("ok");
