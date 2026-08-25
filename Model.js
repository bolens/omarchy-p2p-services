.pragma library

function settingsDefaults() {
  return {
    privacyFilter:true, showStopped:true, showCount:true,
    refreshSeconds:5, backgroundRefreshSeconds:15, reconcileSeconds:60,
    widgetIcon:"󰒍", popupMaxHeight:600, consoleHost:"",
    showLoadingIndicators:true, loadingIndicatorStyle:"spinner",
    loadingIndicatorGlyph:">", loadingIndicatorSpeed:140,
    notifyOnControlChanges:true, autoStartAfterInstall:false,
    showTrafficStats:true, compactCards:false,
    serviceSortMode:"custom", serviceSortDirection:"automatic",
    favoritesFirst:true, runningFirst:false, stableLiveSort:true,
    serviceGroupMode:"none", serviceGroupDirection:"automatic",
    groupCountMode:"active-total", showGroupIcons:true,
    savedViews:[], serviceLayout:"list", cardDensity:"comfortable",
    showStatusRail:true, showFavoriteMarker:true, showBackendBadge:false,
    showCardSummary:true, showQuickActions:true, showGroupCounts:true,
    compactHeader:false, groupHeaderStyle:"surfaced",
    barPresentation:"active", categoryIcons:{}, hideZeroCount:false, barFontSize:14,
    barHorizontalMargin:8, barVerticalPadding:6, barFixedWidth:0,
    barTextRotation:"normal", barForegroundColorRole:"foreground",
    barActiveColorRole:"accent", barDimWhenIdle:false, popupWidth:600,
    runningColorRole:"accent", stoppedColorRole:"muted",
    errorColorRole:"urgent", favoriteColorRole:"accent",
    activityColorRole:"accent", defaultView:"all", defaultSavedView:"",
    persistCollapsedGroups:true, collapsedServiceGroups:{},
    refreshOnOpen:true, refreshAfterSettings:true, refreshAfterActions:true,
    staleWarningSeconds:60, notifyUnexpectedStops:false,
    notifyRecovery:false, notifyUnhealthy:true, notifyRestartEvents:true,
    notificationCooldownSeconds:30, restartWarningThreshold:3,
    trafficSmoothingSeconds:3, trafficMinimumBytesPerSecond:1024,
    favoriteServices:[], serviceNotificationPolicies:{}, eventRefresh:true,
    backupRetention:10, customServices:[], enabledServices:[],
    serviceLabels:{}, serviceIcons:{}, serviceShowStopped:{},
    serviceConsoleUrls:{}, serviceOrder:[]
  }
}

function formatDuration(seconds) {
  var value = Math.max(0, Number(seconds) || 0)
  var days = Math.floor(value / 86400)
  var hours = Math.floor((value % 86400) / 3600)
  var minutes = Math.floor((value % 3600) / 60)
  if (days) return days + "d " + hours + "h"
  if (hours) return hours + "h " + minutes + "m"
  return minutes + "m"
}

function summary(entry, filtered) {
  if (!entry.active) return "Stopped"
  var parts = [entry.connections + " connected", entry.listeners + " listening", "up " + formatDuration(entry.uptime)]
  if (filtered) parts.push("details filtered")
  return parts.join(" · ")
}

function compactIndicators(entry) {
  if (!entry) return []
  var values = []
  var connections = Math.max(0, Number(entry.connections) || 0)
  var listeners = Math.max(0, Number(entry.listeners) || 0)
  var processes = Math.max(0, Number(entry.processCount) || 0)
  if (connections) values.push({icon:"󰌷", value:String(connections), tooltip:connections + " peer connection" + (connections === 1 ? "" : "s") + " · Show details", action:"details"})
  if (listeners) values.push({icon:"󰖟", value:String(listeners), tooltip:listeners + " listening socket" + (listeners === 1 ? "" : "s") + " · Show details", action:"details"})
  if (processes) values.push({icon:"󰆍", value:String(processes), tooltip:processes + " running process" + (processes === 1 ? "" : "es") + " · Show details", action:"details"})
  if (entry.hasWeb === true) values.push({icon:"󰖟", value:"", tooltip:"Open web console", action:"console"})
  if (entry.configExists === true) values.push(entry.controllable === false
    ? {icon:"󰒓", value:"", tooltip:"Configuration detected · Observation only", action:"config", enabled:false}
    : {icon:"󰒓", value:"", tooltip:"Open configuration", action:"config"})
  return values
}

function formatRate(bytesPerSecond) {
  var value = Math.max(0, Number(bytesPerSecond) || 0)
  var units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
  var index = 0
  while (value >= 1024 && index < units.length - 1) { value /= 1024; index++ }
  var digits = value >= 100 || index === 0 ? 0 : 1
  return value.toFixed(digits) + " " + units[index]
}

function loadingFrames(style, glyph) {
  var safeGlyph = String(glyph || "").trim() || ">"
  if (style === "dots") return [".  ", ".. ", "..."]
  if (style === "bar") return ["[=   ]", "[==  ]", "[=== ]", "[ ===]", "[  ==]", "[   =]"]
  if (style === "glyph") return [safeGlyph]
  return ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
}

function loadingFrame(style, glyph, frameIndex) {
  var frames = loadingFrames(style, glyph)
  var index = Math.max(0, Number(frameIndex) || 0) % frames.length
  return frames[index]
}

function matchesSearch(entry, displayLabel, query) {
  var needle = String(query || "").trim().toLocaleLowerCase()
  if (!needle) return true
  var fields = [displayLabel, entry && entry.name, entry && entry.id, entry && entry.category, entry && entry.backend, entry && entry.unit]
  return fields.some(function(value) { return String(value || "").toLocaleLowerCase().indexOf(needle) >= 0 })
}

function matchesStatus(entry, filter) {
  if (filter === "running") return entry && entry.active === true
  if (filter === "stopped") return entry && entry.active !== true
  if (filter === "issues") return entry && entry.active === true && entry.hasError === true
  return true
}

function safeHttpUrl(value) {
  var text = String(value || "").trim()
  if (!text || /[\x00-\x1f\x7f]/.test(text)) return ""
  var match = text.match(/^https?:\/\/([^\/?#]+)/i)
  if (!match || match[1].indexOf("@") >= 0) return ""
  var authority = match[1]
  var host = authority
  var port = ""
  if (authority.charAt(0) === "[") {
    var close = authority.indexOf("]")
    if (close < 2) return ""
    host = authority.slice(1, close)
    port = authority.slice(close + 1)
    var ipv6 = host.match(/^[0-9A-Fa-f:]+/)
    if (!ipv6 || ipv6[0] !== host) return ""
  } else {
    var pieces = authority.split(":")
    if (pieces.length > 2) return ""
    host = pieces[0]
    port = pieces.length === 2 ? ":" + pieces[1] : ""
    var hostname = host.match(/^[A-Za-z0-9.-]+/)
    if (!hostname || hostname[0] !== host || host.indexOf("..") >= 0) return ""
  }
  if (port) {
    var portMatch = port.match(/^:[0-9]{1,5}/)
    if (!portMatch || portMatch[0] !== port || Number(port.slice(1)) > 65535) return ""
  }
  return text
}
function enabled(value, fallback) {
  if (Array.isArray(value)) return value.map(String)
  return fallback || []
}

function serviceNotificationPolicy(policies, id) {
  var values = policies && typeof policies === "object" && !Array.isArray(policies) ? policies : {}
  var policy = values[id] === undefined ? "inherit" : String(values[id])
  return ["inherit", "always", "failures", "silent"].indexOf(policy) >= 0 ? policy : "inherit"
}

function shouldNotifyService(policy, exitCode, fallback) {
  if (policy === "always") return true
  if (policy === "failures") return Number(exitCode) !== 0
  if (policy === "silent") return false
  return fallback === true
}

function serviceMapPatch(settings, key, id, value, removeEmpty) {
  var source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings[key] : null
  var values = source && typeof source === "object" && !Array.isArray(source)
    ? JSON.parse(JSON.stringify(source)) : {}
  if (removeEmpty === true && String(value || "").trim() === "") delete values[id]
  else values[id] = value
  var patch = {}
  patch[key] = values
  return patch
}

function resetServicePatch(settings, id) {
  var source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : {}
  var keys = ["serviceLabels", "serviceIcons", "serviceShowStopped", "serviceConsoleUrls", "serviceNotificationPolicies"]
  var patch = {}
  for (var index = 0; index < keys.length; index++) {
    var update = serviceMapPatch(source, keys[index], id, "", true)
    patch[keys[index]] = update[keys[index]]
  }
  patch.favoriteServices = enabled(source.favoriteServices, []).filter(function(value) { return value !== id })
  return patch
}

function globalSettingsResetPatch(settings) {
  var source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : {}
  var reset = settingsDefaults()
  var preserved = ["serviceLabels", "serviceIcons", "serviceShowStopped", "serviceConsoleUrls",
    "serviceNotificationPolicies", "favoriteServices", "serviceOrder"]
  for (var index = 0; index < preserved.length; index++) {
    var key = preserved[index]
    if (source[key] !== undefined) reset[key] = JSON.parse(JSON.stringify(source[key]))
  }
  return reset
}

function parseCustomServices(raw) {
  var text = String(raw || "").trim()
  if (!text) return {valid:true,services:[]}
  try {
    var parsed = JSON.parse(text)
    return Array.isArray(parsed) ? {valid:true,services:parsed} : {valid:false,services:[]}
  } catch (error) { return {valid:false,services:[]} }
}

function actionNotification(serviceName, requestedAction, exitCode, detail) {
  var name = String(serviceName || "Service")
  var action = String(requestedAction || "update")
  var verb = action.charAt(0).toUpperCase() + action.slice(1)
  if (Number(exitCode) === 0) return {title:"P2P service updated",body:name + " " + action + " completed"}
  if (Number(exitCode) === 126) return {title:"P2P service action cancelled",body:verb + " " + name + " was cancelled"}
  var reason = Number(exitCode) === -2 ? "The operation timed out" : "Check the service and system logs for details"
  return {title:"P2P service action failed",body:verb + " " + name + " failed. " + reason}
}

function mergeServiceStatus(previousEntries, nextEntries, fullScan) {
  var previous = Array.isArray(previousEntries) ? previousEntries : []
  var next = Array.isArray(nextEntries) ? nextEntries : []
  if (fullScan === true) return next.slice()
  var byId = {}, emitted = {}, merged = []
  for (var index = 0; index < next.length; index++) byId[next[index].id] = next[index]
  for (var oldIndex = 0; oldIndex < previous.length; oldIndex++) {
    var oldEntry = previous[oldIndex], current = byId[oldEntry.id]
    if (current) { merged.push(current); emitted[current.id] = true; continue }
    var backend = String(oldEntry.backend || "")
    if (backend.indexOf("docker") < 0 && backend.indexOf("podman") < 0) continue
    var stopped = JSON.parse(JSON.stringify(oldEntry))
    stopped.active = false
    stopped.hasError = false
    stopped.health = "stopped"
    stopped.pids = []
    stopped.processCount = 0
    stopped.connections = 0
    stopped.listeners = 0
    stopped.endpoints = []
    stopped.uptime = 0
    stopped.rxBytes = 0
    stopped.txBytes = 0
    stopped.trafficAvailable = false
    merged.push(stopped)
    emitted[stopped.id] = true
  }
  for (var nextIndex = 0; nextIndex < next.length; nextIndex++) if (!emitted[next[nextIndex].id]) merged.push(next[nextIndex])
  return merged
}

function refreshFailureState(currentFailures, detail) {
  var suffix = String(detail || "").trim()
  return {
    failures:Math.max(0, Number(currentFailures) || 0) + 1,
    error:"Unable to refresh P2P service status; showing the last successful result." + (suffix ? " " + suffix : "")
  }
}

function refreshHealthText(state, now) {
  state = state || {}
  var last = Number(state.lastSuccessfulAt) || 0
  if (!last) return "Waiting for the first successful refresh"
  var age = Math.max(0, Math.round(((Number(now) || Date.now()) - last) / 1000))
  var diagnostics = Math.max(0, Number(state.diagnostics) || 0)
  var failures = Math.max(0, Number(state.failures) || 0)
  var text = String(state.lastScanKind || "Completed scan") + " · " + (Math.max(0, Number(state.durationMs) || 0)) + " ms · updated " + age + "s ago"
  if (age >= Math.max(0, Number(state.staleSeconds) || 0)) text += " · data may be stale"
  if (diagnostics) text += " · " + diagnostics + " partial probe warning" + (diagnostics === 1 ? "" : "s")
  if (failures) text += " · " + failures + " consecutive failure" + (failures === 1 ? "" : "s")
  return text
}

function transitionCooldown(current, id, kind, now, cooldownSeconds) {
  var timestamps = current && typeof current === "object" && !Array.isArray(current) ? Object.assign({}, current) : {}
  var key = id + ":" + kind
  var timestamp = Number(now) || Date.now()
  var cooldown = Math.max(0, Number(cooldownSeconds) || 0) * 1000
  if (timestamps[key] !== undefined && cooldown > 0 && timestamp - Number(timestamps[key] || 0) < cooldown)
    return {allowed:false,timestamps:timestamps}
  timestamps[key] = timestamp
  return {allowed:true,timestamps:timestamps}
}

function parseWatcherEvent(line, now) {
  try {
    var message = JSON.parse(String(line || "{}"))
    if (message.type !== "watch-event" || message.version !== 1) return {accepted:false}
    return {accepted:true,changed:message.kind === "changed",heartbeatAt:Number(now) || Date.now(),
      health:message.healthy === false ? "degraded" : "healthy",code:String(message.code || "ok"),retryMilliseconds:1000}
  } catch (error) { return {accepted:false} }
}

function watcherExitState(enabled, retryMilliseconds) {
  if (enabled !== true) return {retry:false}
  var delay = Math.max(1000, Math.min(60000, Number(retryMilliseconds) || 1000))
  return {retry:true,delay:delay,nextRetryMilliseconds:Math.min(delay * 2, 60000),health:"degraded",code:"watcher_exited"}
}

function watcherHeartbeatState(lastHeartbeatAt, now, thresholdMilliseconds) {
  var last = Number(lastHeartbeatAt) || 0
  var timestamp = Number(now) || Date.now()
  var threshold = Math.max(1, Number(thresholdMilliseconds) || 45000)
  if (last > 0 && timestamp - last <= threshold) return {stale:false}
  return {stale:true,health:"degraded",code:"heartbeat_stale"}
}

function parseTransferredSettings(payload, moduleName, mode) {
  try {
    var parsed = JSON.parse(String(payload || "{}"))
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {valid:false,settings:{}}
    if (mode === "undo") parsed.id = String(moduleName || "")
    return {valid:true,settings:parsed}
  } catch (error) { return {valid:false,settings:{}} }
}

function parseCatalog(payload) {
  try {
    var parsed = JSON.parse(String(payload || ""))
    return Array.isArray(parsed) ? parsed : null
  } catch (error) { return null }
}

function consoleUrlUpdate(value) {
  var input = String(value || "").trim()
  if (!input) return {valid:true,url:""}
  var url = safeHttpUrl(input)
  return url ? {valid:true,url:url} : {valid:false,url:""}
}

function refreshBackoff(failures) {
  return Math.pow(2, Math.min(2, Math.max(0, Number(failures) || 0)))
}

function mergeRefreshRequest(current, forceCatalog, fullContainers, bypassCache) {
  var pending = current || {}
  return {
    forceCatalog: pending.forceCatalog === true || forceCatalog === true,
    fullContainers: pending.fullContainers === true || fullContainers === true,
    bypassCache: pending.bypassCache === true || bypassCache === true
  }
}

function compareServices(a, b, context) {
  var options = context || {}
  if (options.groupMode && options.groupMode !== "none") {
    var aGroup = groupLabel(a, options.groupMode, options.favorites && options.favorites[a.id] === true)
    var bGroup = groupLabel(b, options.groupMode, options.favorites && options.favorites[b.id] === true)
    var groupDelta = compareGroupLabels(aGroup, bGroup, options.groupMode, options.groupDirection)
    if (groupDelta) return groupDelta
  }
  if (options.favoritesFirst !== false) {
    var favoriteDelta = (options.favorites && options.favorites[a.id] ? 0 : 1) - (options.favorites && options.favorites[b.id] ? 0 : 1)
    if (favoriteDelta) return favoriteDelta
  }
  if (options.runningFirst === true) {
    var runningDelta = (a.active ? 0 : 1) - (b.active ? 0 : 1)
    if (runningDelta) return runningDelta
  }
  var mode = String(options.mode || "custom")
  var av = 0, bv = 0, naturalDescending = false
  if (mode === "name") {
    av = String(options.labels && options.labels[a.id] || a.name || a.id)
    bv = String(options.labels && options.labels[b.id] || b.name || b.id)
  } else if (mode === "backend") {
    av = String(a.backend || "")
    bv = String(b.backend || "")
  } else if (mode === "category") {
    av = String(a.category || "")
    bv = String(b.category || "")
  } else if (mode === "status") {
    av = a.hasError ? 0 : (a.active ? 1 : 2)
    bv = b.hasError ? 0 : (b.active ? 1 : 2)
  } else if (mode === "activity") {
    var ar = options.trafficRates && options.trafficRates[a.id]
    var br = options.trafficRates && options.trafficRates[b.id]
    av = a.hasError ? 0 : (options.pendingService === a.id ? 1 : (a.active && ar && ar.active === true ? 2 : (a.active ? 3 : 4)))
    bv = b.hasError ? 0 : (options.pendingService === b.id ? 1 : (b.active && br && br.active === true ? 2 : (b.active ? 3 : 4)))
  } else if (mode === "connections") {
    av = Number(a.connections) || 0; bv = Number(b.connections) || 0; naturalDescending = true
  } else if (mode === "uptime") {
    av = Number(a.uptime) || 0; bv = Number(b.uptime) || 0; naturalDescending = true
  } else if (mode === "traffic") {
    var at = options.trafficRates && options.trafficRates[a.id] || {}
    var bt = options.trafficRates && options.trafficRates[b.id] || {}
    av = (Number(at.rx) || 0) + (Number(at.tx) || 0)
    bv = (Number(bt.rx) || 0) + (Number(bt.tx) || 0)
    naturalDescending = true
  } else if (mode === "recent") {
    av = Date.parse(a.lastTransition || "") || 0
    bv = Date.parse(b.lastTransition || "") || 0
    naturalDescending = true
  } else if (mode === "errors") {
    av = (a.hasError ? 1000000 : 0) + (a.failureReason ? 100000 : 0) + (Number(a.restartCount) || 0)
    bv = (b.hasError ? 1000000 : 0) + (b.failureReason ? 100000 : 0) + (Number(b.restartCount) || 0)
    naturalDescending = true
  } else {
    av = options.orderRanks && options.orderRanks[a.id]
    bv = options.orderRanks && options.orderRanks[b.id]
    if (av === undefined) av = 1000 + Number(options.sourceRanks && options.sourceRanks[a.id] || 0)
    if (bv === undefined) bv = 1000 + Number(options.sourceRanks && options.sourceRanks[b.id] || 0)
  }
  var delta = typeof av === "string" ? av.localeCompare(bv) : av - bv
  var direction = String(options.direction || "automatic")
  if (direction === "descending" || (direction === "automatic" && naturalDescending)) delta = -delta
  if (delta) return delta
  var aLabel = String(options.labels && options.labels[a.id] || a.name || a.id)
  var bLabel = String(options.labels && options.labels[b.id] || b.name || b.id)
  var labelDelta = aLabel.localeCompare(bLabel)
  if (labelDelta) return labelDelta
  return Number(options.sourceRanks && options.sourceRanks[a.id] || 0) - Number(options.sourceRanks && options.sourceRanks[b.id] || 0)
}

function sortServices(entries, context, previousOrder, freeze) {
  var result = (entries || []).slice()
  if (freeze === true && previousOrder && previousOrder.length) {
    var ranks = {}
    for (var index = 0; index < previousOrder.length; index++) ranks[previousOrder[index]] = index
    result.sort(function(a, b) {
      if (context && context.groupMode && context.groupMode !== "none") {
        var aGroup = groupLabel(a, context.groupMode, context.favorites && context.favorites[a.id] === true)
        var bGroup = groupLabel(b, context.groupMode, context.favorites && context.favorites[b.id] === true)
        var groupDelta = compareGroupLabels(aGroup, bGroup, context.groupMode, context.groupDirection)
        if (groupDelta) return groupDelta
      }
      var ai = ranks[a.id] === undefined ? 100000 : ranks[a.id]
      var bi = ranks[b.id] === undefined ? 100000 : ranks[b.id]
      return ai - bi || compareServices(a, b, context)
    })
    return result
  }
  result.sort(function(a, b) { return compareServices(a, b, context) })
  return result
}

function groupLabel(entry, mode, favorite) {
  if (mode === "status") return entry && entry.hasError ? "NEEDS ATTENTION" : (entry && entry.active ? "RUNNING" : "STOPPED")
  if (mode === "backend") return String(entry && entry.backend || "OTHER").toUpperCase()
  if (mode === "category") return String(entry && entry.category || "OTHER").toUpperCase()
  if (mode === "scope") {
    var backend = String(entry && entry.backend || "")
    if ((entry && entry.runtimes && entry.runtimes.length) || backend.indexOf("docker") >= 0 || backend.indexOf("podman") >= 0) return "CONTAINERS"
    if (entry && entry.unitScope === "user") return "USER SERVICES"
    if (entry && entry.unitScope === "system" || backend === "systemd") return "SYSTEM SERVICES"
    return "PROCESSES"
  }
  if (mode === "favorite") return favorite === true ? "FAVORITES" : "OTHER SERVICES"
  return ""
}

function compareGroupLabels(a, b, mode, direction) {
  var left = String(a || ""), right = String(b || ""), order = String(direction || "automatic")
  if (order === "automatic") {
    var ranks = mode === "status"
      ? {"NEEDS ATTENTION":0,"RUNNING":1,"STOPPED":2}
      : (mode === "favorite" ? {"FAVORITES":0,"OTHER SERVICES":1}
        : (mode === "scope" ? {"CONTAINERS":0,"SYSTEM SERVICES":1,"USER SERVICES":2,"PROCESSES":3} : null))
    if (ranks) {
      var leftRank = ranks[left] === undefined ? 100 : ranks[left]
      var rightRank = ranks[right] === undefined ? 100 : ranks[right]
      if (leftRank !== rightRank) return leftRank - rightRank
    }
  }
  var delta = left.localeCompare(right)
  return order === "descending" ? -delta : delta
}

function groupCountText(entries, mode) {
  var rows = entries || [], active = rows.filter(function(entry) { return entry && entry.active === true }).length
  if (mode === "active") return active + " active"
  if (mode === "total") return String(rows.length)
  return active + "/" + rows.length + " active"
}

function serviceIndexes(entries, favoriteIds, groupMode) {
  var rows = entries || [], favorites = {}, byId = {}, groups = {}, active = 0, errors = 0
  ;(favoriteIds || []).forEach(function(id) { favorites[String(id)] = true })
  rows.forEach(function(entry) {
    if (!entry || !entry.id) return
    byId[entry.id] = entry
    if (entry.active === true) active++
    if (entry.active === true && entry.hasError === true) errors++
    var label = groupLabel(entry, groupMode, favorites[entry.id] === true)
    if (label) {
      if (!groups[label]) groups[label] = {active:0,total:0}
      groups[label].total++
      if (entry.active === true) groups[label].active++
    }
  })
  return {byId:byId,favorites:favorites,groups:groups,active:active,errors:errors,total:rows.length}
}

function indexedGroupCountText(summary, label, mode) {
  var row = summary && summary.groups && summary.groups[label] || {active:0,total:0}
  if (mode === "active") return row.active + " active"
  if (mode === "total") return String(row.total)
  return row.active + "/" + row.total + " active"
}

function groupIcon(entry, mode, favorite, categoryIcons) {
  if (mode === "category") return String(categoryIcons && categoryIcons[entry.category] || entry && entry.icon || "󰒍")
  if (mode === "favorite") return favorite === true ? "󰓎" : "󰒍"
  if (mode === "status") return entry && entry.hasError ? "󰅚" : (entry && entry.active ? "󰐊" : "󰓛")
  if (mode === "scope") {
    var label = groupLabel(entry, mode, favorite)
    if (label === "CONTAINERS") return "󰡨"
    if (label === "SYSTEM SERVICES") return "󰒓"
    if (label === "USER SERVICES") return "󰀄"
    return "󰆍"
  }
  return "󰒍"
}

function organizationChanged(patch) {
  var values = patch || {}, keys = [
    "serviceSortMode", "serviceSortDirection", "serviceGroupMode",
    "serviceGroupDirection", "favoritesFirst", "runningFirst",
    "favoriteServices", "serviceOrder", "serviceLabels", "stableLiveSort"
  ]
  return keys.some(function(key) { return Object.prototype.hasOwnProperty.call(values, key) })
}

function categorySummaries(entries, iconOverrides, includeTotal, hideZero) {
  var groups = {}, icons = iconOverrides || {}
  ;(entries || []).forEach(function(entry) {
    var category = String(entry && entry.category || "Other")
    if (!groups[category]) groups[category] = {category:category,icon:String(icons[category] || entry.icon || "󰒍"),active:0,total:0}
    groups[category].total++
    if (entry.active === true) groups[category].active++
  })
  return Object.keys(groups).sort(function(a, b) { return a.localeCompare(b) }).map(function(category) {
    var row = groups[category]
    row.text = row.icon + " " + row.active + (includeTotal === true ? "/" + row.total : "")
    return row
  }).filter(function(row) { return hideZero !== true || row.active > 0 })
}

function barPresentationText(entries, mode, icon, categoryIcons, hideZero) {
  var rows = entries || [], fallback = String(icon || "󰒍")
  var active = rows.filter(function(entry) { return entry && entry.active === true }).length
  var errors = rows.filter(function(entry) { return entry && entry.active === true && entry.hasError === true }).length
  if (mode === "category-active" || mode === "category-active-total") {
    var categories = categorySummaries(rows, categoryIcons || {}, mode === "category-active-total", hideZero === true)
    return categories.length ? categories.map(function(row) { return row.text }).join("  ") : fallback
  }
  if (mode === "icon") return fallback
  if (mode === "health") return fallback + (errors ? " !" : (active ? " ●" : ""))
  if (hideZero === true && active === 0) return fallback
  if (mode === "active-total") return fallback + " " + active + "/" + rows.length
  return fallback + " " + active
}

function categoryIconMap(current, category, icon) {
  var values = Object.assign({}, current || {}), next = String(icon || "").trim()
  if (next) values[String(category)] = next
  else delete values[String(category)]
  return values
}

function savedViewPatch(view) {
  var selected = view || {}
  return {
    serviceSortMode:String(selected.sortMode || "custom"),
    serviceSortDirection:String(selected.sortDirection || "automatic"),
    serviceGroupMode:String(selected.groupMode || "none"),
    serviceGroupDirection:String(selected.groupDirection || "automatic"),
    favoritesFirst:selected.favoritesFirst !== false
  }
}

function savedViewSelection(view) {
  var selected = view || {}
  return {search:String(selected.search || ""),filter:String(selected.filter || "all"),patch:savedViewPatch(selected)}
}

function smoothTrafficRate(previous, current, alpha, threshold) {
  var prior = previous || {}, next = current || {}
  var weight = Math.max(0, Math.min(1, Number(alpha) || 0))
  var rx = (Number(prior.rx) || 0) * (1 - weight) + (Number(next.rx) || 0) * weight
  var tx = (Number(prior.tx) || 0) * (1 - weight) + (Number(next.tx) || 0) * weight
  return {rx: rx, tx: tx, active: rx + tx >= Math.max(0, Number(threshold) || 0)}
}

function serviceTransitions(previous, next, restartThreshold) {
  var oldById = {}, changes = [], threshold = Math.max(1, Number(restartThreshold) || 1)
  previous = Array.isArray(previous) ? previous : []
  next = Array.isArray(next) ? next : []
  for (var oldIndex = 0; oldIndex < previous.length; oldIndex++) oldById[previous[oldIndex].id] = previous[oldIndex]
  for (var index = 0; index < next.length; index++) {
    var entry = next[index], old = oldById[entry.id]
    if (!old) continue
    if (old.active === true && entry.active !== true) changes.push({id:entry.id,kind:"stopped"})
    if (old.hasError === true && entry.active === true && entry.hasError !== true) changes.push({id:entry.id,kind:"recovered"})
    if (old.hasError !== true && entry.hasError === true) changes.push({id:entry.id,kind:"unhealthy"})
    var restarts = Number(entry.restartCount) || 0
    if (restarts >= threshold && restarts > (Number(old.restartCount) || 0)) changes.push({id:entry.id,kind:"restarts",count:restarts})
  }
  return changes
}

function ensureVisibleContentY(currentY, viewportHeight, itemTop, itemHeight, contentHeight) {
  var current = Math.max(0, Number(currentY) || 0)
  var viewport = Math.max(0, Number(viewportHeight) || 0)
  var top = Math.max(0, Number(itemTop) || 0)
  var height = Math.max(0, Number(itemHeight) || 0)
  var maximum = Math.max(0, (Number(contentHeight) || 0) - viewport)
  var target = current
  if (height >= viewport || top < current) target = top
  else if (top + height > current + viewport) target = top + height - viewport
  return Math.max(0, Math.min(maximum, target))
}

function nextSelectionIndex(count, currentIndex, delta) {
  var size = Math.max(0, Number(count) || 0)
  if (!size) return -1
  var direction = Number(delta) < 0 ? -1 : 1
  var current = Number(currentIndex)
  if (current < 0 || current >= size) current = direction < 0 ? size : -1
  return Math.max(0, Math.min(size - 1, current + direction))
}
