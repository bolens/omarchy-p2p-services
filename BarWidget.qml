import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "PathUtils.js" as PathUtils

Panel {
  id: root
  moduleName: "io.github.bolens.p2p-services"
  manageIpc: false
  readonly property var p2pService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  property var services: []
  property var serviceCatalog: []
  property var trafficHistory: ({})
  property var trafficRates: ({})
  property var collapsedServiceGroups: ({})
  property var notificationLastAt: ({})
  property var controlledUntil: ({})
  readonly property var eventJournal: journal.events
  property bool initialViewApplied: false
  property bool statusLoading: true
  property int barLoadingFrameIndex: 0
  readonly property bool statusIndicatorVisible: statusLoadingState.visible
  property var helperDiagnostics: []
  readonly property var durableSettings: settingsStore.durableSettings
  readonly property var settingsStoreController: settingsStore
  readonly property bool durableSettingsLoaded: settingsStore.loaded
  readonly property bool settingsSurfaceLoaded: settingsPageLoader.item !== null
  readonly property bool serviceLoadingVisible: serviceLoadingIndicator.visible
  readonly property bool serviceFiltersRowVisible: serviceFilterBar.visible
  property url settingsSurfaceSource: ""
  readonly property bool catalogLoading: catalogLoadingState.visible
  property double refreshStartedAt: 0
  property double lastSuccessfulRefreshAt: 0
  property int lastRefreshDurationMs: 0
  property int consecutiveRefreshFailures: 0
  property string lastScanKind: "Not started"
  property string errorText: ""
  property string catalogErrorText: ""
  property string settingsErrorText: ""
  readonly property string visibleErrorText: settingsErrorText || catalogErrorText || errorText
  property string pendingService: ""
  property string pendingServiceName: ""
  property string pendingAction: ""
  property string searchQuery: ""
  property string serviceFilter: "all"
  property string backendFilter: ""
  property bool serviceFiltersExpanded: false
  property string expandedServiceId: ""
  property string contextServiceId: ""
  property string selectedServiceId: ""
  property string editingServiceId: ""
  property string settingsPage: "general"
  property string settingsSection: ""
  property bool showingWidgetSettings: false
  property bool availablePackagesExpanded: false
  readonly property bool settingsTransferRunning: settingsTransferController.running
  readonly property bool settingsPersistenceRunning: settingsStore.running || settingsStore.loading
  readonly property bool settingsUndoAvailable: settingsTransferController.undoAvailable
  readonly property bool settingsTransferLoading: settingsTransferLoadingState.visible
  property string settingsTransferDisplayMode: ""
  property string settingsSaveStatus: ""
  property bool installedPackagesExpanded: false
  property var privacyFilterOverride: undefined
  property bool privacyToggleInProgress: false
  property bool fullContainerScanPending: true
  property int catalogBurstRemaining: 0
  readonly property bool settingsIndicatorVisible: settingsLoadingState.visible
  readonly property var uninstallTarget: confirmationState.uninstallTarget
  readonly property bool uninstallConfirmOpen: confirmationState.uninstallOpen
  readonly property var restoreTarget: confirmationState.restoreTarget
  readonly property string restoreBackupName: confirmationState.restoreBackupName
  readonly property bool restoreConfirmOpen: confirmationState.restoreOpen
  readonly property bool privacyFilter: privacyFilterOverride !== undefined
    ? privacyFilterOverride === true
    : setting("privacyFilter", true) === true
  readonly property bool showStopped: setting("showStopped", true) === true
  readonly property int refreshSeconds: Math.max(2, Math.min(60, Number(setting("refreshSeconds", 5)) || 5))
  readonly property int backgroundRefreshSeconds: Math.max(15, Math.min(300, Number(setting("backgroundRefreshSeconds", 15)) || 15))
  readonly property int reconcileSeconds: Math.max(30, Math.min(600, Number(setting("reconcileSeconds", 60)) || 60))
  readonly property bool intrinsicMainWidth: editingServiceId === "" && !showingWidgetSettings && expandedServiceId === "" && serviceList.contentWidthHint > 0
  readonly property real configuredPanelWidth: Style.space(Math.max(420, Math.min(800, Number(setting("popupWidth", 600)) || 600)))
  readonly property real configuredPanelHeight: Style.space(Math.max(360, Math.min(900, Number(setting("popupMaxHeight", 600)) || 600)))
  readonly property real scrollbarGutter: popupScrollBar.visible ? popupScrollBar.implicitWidth + Style.spacing.xs : 0
  readonly property real desiredPanelWidth: intrinsicMainWidth ? Math.min(configuredPanelWidth, serviceList.contentWidthHint + scrollbarGutter) : configuredPanelWidth
  readonly property int pollIntervalMilliseconds: (opened ? refreshSeconds : Math.max(backgroundRefreshSeconds, refreshSeconds)) * 1000 * Model.refreshBackoff(consecutiveRefreshFailures)
  readonly property var visibleServices: {
    var revision = organizationState.revision
    return filteredServices()
  }
  readonly property var serviceIndexes: Model.serviceIndexes(services, Model.enabled(setting("favoriteServices", []), []), String(setting("serviceGroupMode", "none")))
  readonly property int activeCount: serviceIndexes.active
  readonly property int stoppedCount: serviceIndexes.total - activeCount
  readonly property int errorCount: serviceIndexes.errors
  readonly property var catalogIndexes: Model.catalogIndexes(serviceCatalog)
  readonly property var missingServices: catalogIndexes.missing
  readonly property var detectedServiceCatalog: catalogIndexes.detected
  readonly property var visibleMissingServices: availablePackagesExpanded ? missingServices : missingServices.slice(0, 5)
  readonly property var visibleDetectedServiceCatalog: installedPackagesExpanded ? detectedServiceCatalog : detectedServiceCatalog.slice(0, 5)
  property string helper: PathUtils.localFilePath(Qt.resolvedUrl("p2p-control"))
  readonly property real openPanelIndicatorWidth: button.labelWidth

  function setting(key, fallback) {
    if (durableSettingsLoaded && durableSettings && durableSettings[key] !== undefined) return durableSettings[key]
    return settings && settings[key] !== undefined ? settings[key] : fallback
  }
  function syncService() {
    if (!p2pService || typeof p2pService.configure !== "function") return
    var source = durableSettingsLoaded ? durableSettings : settings
    var operational = JSON.parse(JSON.stringify(source || {}))
    operational.privacyFilter = privacyFilter
    p2pService.configure(operational)
  }
  function monitoringTelemetryText() {
    if (!p2pService || typeof p2pService.monitoringTelemetry !== "function") return "Shared monitor unavailable; this widget is using its local fallback."
    var data = p2pService.monitoringTelemetry()
    return "Watcher " + data.watcherHealth + " (" + data.watcherCode + ")"
      + " · heartbeat " + (data.watcherHeartbeatAgeSeconds < 0 ? "waiting" : data.watcherHeartbeatAgeSeconds + "s ago")
      + " · retry " + data.watcherRetryMilliseconds + " ms"
      + "\nSettings sync " + data.settingsWatcherHealth + " (" + data.settingsWatcherCode + ")"
      + " · event " + (data.settingsWatcherLastEventAgeSeconds < 0 ? "waiting" : data.settingsWatcherLastEventAgeSeconds + "s ago")
      + " · retry " + data.settingsWatcherRetryMilliseconds + " ms"
      + "\nLast shared scan " + (data.lastRefreshAgeSeconds < 0 ? "waiting" : data.lastRefreshAgeSeconds + "s ago")
      + " · " + data.lastDurationMs + " ms · " + data.diagnostics + " warning" + (data.diagnostics === 1 ? "" : "s")
  }
  function writeDurableSettings(next, patch) {
    settingsSaveStatus = "saving"
    settingsSavedClear.stop()
    settingsStore.save(next, patch)
  }
  function restoreFailedSettings() {
    var fallback = JSON.parse(JSON.stringify(durableSettings || settings || {}))
    fallback.id = moduleName
    settings = fallback
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function") bar.shell.updateEntryInline(moduleName, fallback)
    settingsSaveStatus = "failed"
    errorText = "Unable to save P2P widget settings; previous settings restored"
  }
  function adoptTransferredSettings(imported) {
    settingsStore.adopt(imported)
    settings = imported
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function") bar.shell.updateEntryInline(moduleName, imported)
  }
  function filteredServices() {
    var allow = Model.enabled(setting("enabledServices", []), [])
    var allowed = {}
    var stopped = setting("serviceShowStopped", {}) || {}
    var order = Model.enabled(setting("serviceOrder", []), [])
    var sortMode = String(setting("serviceSortMode", "custom"))
    var orderRanks = {}, sourceRanks = {}, favoriteMap = serviceIndexes.favorites, labels = {}
    for (var allowIndex = 0; allowIndex < allow.length; allowIndex++) allowed[allow[allowIndex]] = true
    for (var orderIndex = 0; orderIndex < order.length; orderIndex++) orderRanks[order[orderIndex]] = orderIndex
    for (var sourceIndex = 0; sourceIndex < services.length; sourceIndex++) {
      sourceRanks[services[sourceIndex].id] = sourceIndex
      labels[services[sourceIndex].id] = labelFor(services[sourceIndex])
    }
    var result = services.filter(function(s) {
      var show = serviceFilter === "stopped" ? true : (stopped[s.id] !== undefined ? stopped[s.id] === true : showStopped)
      return (show || s.active)
        && (allow.length === 0 || allowed[s.id] === true)
        && Model.matchesSearch(s, labels[s.id], searchQuery)
        && Model.matchesStatus(s, serviceFilter)
        && Model.matchesBackend(s, backendFilter)
    })
    var sortContext = {
      mode: sortMode,
      direction: String(setting("serviceSortDirection", "automatic")),
      favoritesFirst: setting("favoritesFirst", true) === true,
      favorites: favoriteMap,
      labels: labels,
      orderRanks: orderRanks,
      sourceRanks: sourceRanks,
      trafficRates: trafficRates,
      pendingService: pendingService
    }
    sortContext.runningFirst = setting("runningFirst", false) === true
    sortContext.groupMode = String(setting("serviceGroupMode", "none"))
    sortContext.groupDirection = String(setting("serviceGroupDirection", "automatic"))
    return Model.sortServices(result, sortContext, organizationState.stableOrder,
      setting("stableLiveSort", true) === true && (popupScroll.moving || organizationState.stableOrder.length > 0))
  }
  function captureSortOrder() {
    if (setting("stableLiveSort", true) !== true) return
    if (organizationState.capture(visibleServices.map(function(entry) { return entry.id }), true)) sortStabilityTimer.restart()
  }
  function groupLabelFor(entry) { return Model.groupLabel(entry, String(setting("serviceGroupMode", "none")), isFavorite(entry.id)) }
  function showGroupHeading(index, groupName) {
    if (groupName === "") return false
    if (index === 0) return true
    var previous = visibleServices[index - 1]
    return !previous || visibleServiceIndexes.groupById[previous.id] !== groupName
  }
  readonly property var visibleServiceIndexes: Model.serviceIndexes(visibleServices, Model.enabled(setting("favoriteServices", []), []), String(setting("serviceGroupMode", "none")))
  readonly property var visibleServiceGroupNames: Object.keys(visibleServiceIndexes.groups || {})
  readonly property bool serviceGroupsVisible: visibleServiceGroupNames.length > 0
  readonly property bool allServiceGroupsCollapsed: serviceGroupsVisible && visibleServiceGroupNames.every(function(label) { return isGroupCollapsed(label) })
  function groupCountText(label) { return Model.indexedGroupCountText(visibleServiceIndexes, label, String(setting("groupCountMode", "active-total"))) }
  function groupIcon(entry) { return Model.groupIcon(entry, String(setting("serviceGroupMode", "none")), isFavorite(entry.id), setting("categoryIcons", {}) || {}) }
  function isGroupCollapsed(label) { return collapsedServiceGroups[label] === true }
  function toggleGroup(label) {
    var next = Object.assign({}, collapsedServiceGroups); next[label] = next[label] !== true; collapsedServiceGroups = next
    if (setting("persistCollapsedGroups", true) === true) persistQuietly({collapsedServiceGroups:next})
  }
  function setAllServiceGroupsCollapsed(collapsed) {
    if (!serviceGroupsVisible) return
    var next = Object.assign({}, collapsedServiceGroups)
    visibleServiceGroupNames.forEach(function(label) {
      if (collapsed === true) next[label] = true
      else delete next[label]
    })
    collapsedServiceGroups = next
    if (setting("persistCollapsedGroups", true) === true) persistQuietly({collapsedServiceGroups:next})
  }
  function applyView(view) {
    if (!view) return
    var selected = Model.savedViewSelection(view)
    searchQuery = selected.search
    serviceFilter = selected.filter
    backendFilter = selected.backend
    persistKeepingOpen(selected.patch)
  }
  function saveCurrentView(name) {
    var label = String(name || "").trim()
    if (!label) return
    var views = JSON.parse(JSON.stringify(setting("savedViews", []) || []))
    views = views.filter(function(view) { return view.name !== label })
    views.unshift({name:label,filter:serviceFilter,backend:backendFilter,sortMode:String(setting("serviceSortMode","custom")),sortDirection:String(setting("serviceSortDirection","automatic")),groupMode:String(setting("serviceGroupMode","none")),groupDirection:String(setting("serviceGroupDirection","automatic")),favoritesFirst:setting("favoritesFirst",true) === true,search:searchQuery})
    persistKeepingOpen({savedViews:views.slice(0,12)})
  }
  function removeSavedView(name) { persistKeepingOpen({savedViews:(setting("savedViews",[]) || []).filter(function(view) { return view.name !== name })}) }
  function applyInitialView() {
    if (initialViewApplied) return
    initialViewApplied = true
    collapsedServiceGroups = setting("persistCollapsedGroups", true) === true ? (setting("collapsedServiceGroups", {}) || {}) : ({})
    var savedName = String(setting("defaultSavedView", ""))
    var saved = (setting("savedViews", []) || []).find(function(view) { return view.name === savedName })
    if (saved) applyView(saved)
    else { serviceFilter = String(setting("defaultView", "all")); backendFilter = "" }
  }
  function service(id) { return serviceIndexes.byId[id] || null }
  function activityRank(entry) {
    if (entry.hasError) return 0
    if (pendingService === entry.id) return 1
    if (entry.active && trafficRate(entry.id, "active") === true) return 2
    return entry.active ? 3 : 4
  }
  function isFavorite(id) { return serviceIndexes.favorites[id] === true }
  function toggleFavorite(id) {
    var values = Model.enabled(setting("favoriteServices", []), []).slice()
    var index = values.indexOf(id)
    if (index >= 0) values.splice(index, 1); else values.push(id)
    persistKeepingOpen({favoriteServices: values})
  }
  function toggleServiceContext(id) { captureSortOrder(); contextServiceId = contextServiceId === id ? "" : id }
  function toggleServiceDetails(id) { expandedServiceId = expandedServiceId === id ? "" : id }
  function selectableServices() {
    return visibleServices.filter(function(entry) { return !isGroupCollapsed(groupLabelFor(entry)) })
  }
  function moveServiceSelection(delta) {
    var rows = selectableServices()
    if (!rows.length) { selectedServiceId = ""; return }
    var index = rows.findIndex(function(entry) { return entry.id === selectedServiceId })
    index = Model.nextSelectionIndex(rows.length, index, delta)
    var nextId = rows[index].id
    selectedServiceId = nextId
    Qt.callLater(function() { ensureServiceVisible(nextId) })
  }
  function ensureServiceVisible(serviceId) {
    var item = serviceList.itemForId(serviceId)
    if (!item || !opened) return
    var contentPosition = item.mapToItem(popupScroll.contentItem, 0, 0)
    popupScroll.contentY = Model.ensureVisibleContentY(
      popupScroll.contentY, popupScroll.height, contentPosition.y, item.height, popupScroll.contentHeight)
  }
  function serviceIsVisible(serviceId) {
    var item = serviceList.itemForId(serviceId)
    if (!item || !opened) return false
    var contentPosition = item.mapToItem(popupScroll.contentItem, 0, 0)
    return contentPosition.y < popupScroll.contentY + popupScroll.height
      && contentPosition.y + item.height > popupScroll.contentY
  }
  function activateServiceSelection() {
    var rows = selectableServices()
    if (!rows.length) { selectedServiceId = ""; return }
    if (!rows.some(function(entry) { return entry.id === selectedServiceId })) selectedServiceId = rows[0].id
    toggleServiceDetails(selectedServiceId)
  }
  function closeCurrentLayer() {
    if (searchQuery !== "") { searchQuery = ""; return }
    if (backendFilter !== "") { backendFilter = ""; return }
    if (serviceFiltersExpanded) { serviceFiltersExpanded = false; return }
    if (contextServiceId !== "") { contextServiceId = ""; return }
    if (expandedServiceId !== "") { expandedServiceId = ""; return }
    if (editingServiceId !== "") { editingServiceId = ""; return }
    if (showingWidgetSettings) { showingWidgetSettings = false; return }
    close()
  }
  function editService(id) { editingServiceId = id; refreshCatalog() }
  function canMoveServiceEditor(id, delta) {
    var rows = visibleServices
    var index = rows.findIndex(function(entry) { return entry.id === id })
    return index >= 0 && index + delta >= 0 && index + delta < rows.length
  }
  function moveServiceEditor(delta) {
    var rows = visibleServices
    var index = rows.findIndex(function(entry) { return entry.id === editingServiceId })
    if (index < 0 || index + delta < 0 || index + delta >= rows.length) return
    editingServiceId = rows[index + delta].id
    selectedServiceId = editingServiceId
    popupScroll.contentY = 0
    refreshCatalog()
  }
  function serviceNotificationPolicy(id) {
    return Model.serviceNotificationPolicy(setting("serviceNotificationPolicies", {}), id)
  }
  function shouldNotifyService(id, exitCode) {
    return Model.shouldNotifyService(serviceNotificationPolicy(id), exitCode, setting("notifyOnControlChanges", true))
  }
  function showSettingsPage(page) {
    settingsPage = page
    settingsSection = ""
    if (page === "discovery") settingsTransferController.refreshUndoAvailability()
    popupScroll.contentY = 0
    if (page === "packages") refreshCatalog()
  }
  function applySettingsScroll(position) {
    var requested = String(position || "")
    if (requested !== "top" && requested !== "bottom") return "invalid position"
    if (!showingWidgetSettings) return "settings closed"
    popupScroll.contentY = requested === "bottom" ? Math.max(0, popupScroll.contentHeight - popupScroll.height) : 0
    return "ok"
  }
  function setSettingsScroll(position) {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applySettingsScroll === "function") return target.applySettingsScroll(position)
    return applySettingsScroll(position)
  }
  function showSettingsSection(page, section) {
    settingsPage = page
    settingsSection = section
    editingServiceId = ""
    showingWidgetSettings = true
    if (page === "discovery") settingsTransferController.refreshUndoAvailability()
    if (page === "packages") refreshCatalog()
    Qt.callLater(scrollToSettingsSection)
  }
  function scrollToSettingsSection() {
    if (!settingsSection || !settingsPageLoader.item || typeof settingsPageLoader.item.sectionY !== "function") return
    var target = settingsPageLoader.y + Number(settingsPageLoader.item.sectionY(settingsSection) || 0)
    popupScroll.contentY = Math.max(0, Math.min(popupScroll.contentHeight - popupScroll.height, target - Style.spacing.md))
  }
  function settingsPageDescription() {
    if (settingsPage === "appearance") return "BAR, PANEL, AND SERVICE CARDS"
    if (settingsPage === "services") return "SORTING, GROUPING, AND SAVED VIEWS"
    if (settingsPage === "performance") return "REFRESH AND RESOURCE USE"
    if (settingsPage === "discovery") return "ROUTING AND SERVICE FILTERS"
    if (settingsPage === "packages") return "INSTALL AND REMOVE SERVICES"
    return "BEHAVIOR AND APPEARANCE"
  }
  function trafficRate(id, key) { var rate = trafficRates ? trafficRates[id] : null; return rate && rate[key] !== undefined ? rate[key] : 0 }
  function themeColor(role, fallback) {
    if (role === "bar-active") return Color.bar.active
    if (role === "urgent") return Color.urgent
    if (role === "accent") return Color.accent
    if (role === "foreground") return bar ? bar.barForeground : Color.foreground
    if (role === "muted") return Color.muted
    return fallback
  }
  function serviceColor(entry) {
    if (!entry || !entry.active) return themeColor(String(setting("stoppedColorRole", "muted")), Color.muted)
    if (entry.hasError) return themeColor(String(setting("errorColorRole", "urgent")), Color.urgent)
    return themeColor(String(setting("runningColorRole", "accent")), Color.accent)
  }
  function barText() {
    if (statusLoading && setting("showLoadingIndicators", true) === true) {
      return String(setting("widgetIcon", "󰒍")) + " " + Model.loadingFrame(
        String(setting("loadingIndicatorStyle", "spinner")),
        String(setting("loadingIndicatorGlyph", ">")), barLoadingFrameIndex)
    }
    var presentation = Model.barPresentationText(services, String(setting("barPresentation", "active")),
      String(setting("widgetIcon", "󰒍")), setting("categoryIcons", {}) || {},
      setting("hideZeroCount", false) === true, serviceIndexes)
    return presentation + (consecutiveRefreshFailures > 0 ? " ~" : "")
  }
  function barRotation() {
    var rotation = String(setting("barTextRotation", "normal"))
    if (rotation === "clockwise") return 90
    if (rotation === "counterclockwise") return -90
    return 0
  }
  function focusedPanelInstance() {
    if (bar && typeof bar.findPanelWidget === "function") return bar.findPanelWidget(moduleName)
    return root
  }
  function captureContractVersion() { return "2" }
  function openFocused() {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.open === "function") target.open()
    else open()
  }
  function applyMainView() {
    editingServiceId = ""
    showingWidgetSettings = false
    if (!opened) open()
    return "ok"
  }
  function openMainView() {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applyMainView === "function") return target.applyMainView()
    return applyMainView()
  }
  function focusedMainReady(layout, density) {
    var target = focusedPanelInstance()
    return !!target && target.opened === true && target.showingWidgetSettings !== true
      && target.editingServiceId === "" && target.statusIndicatorVisible !== true
      && Array.isArray(target.services) && target.services.length > 0
      && String(target.setting("serviceLayout", "list")) === String(layout)
      && String(target.setting("cardDensity", "comfortable")) === String(density)
  }
  function applyServiceDetails(serviceId) {
    var requested = String(serviceId || "")
    var found = services.some(function(entry) { return entry.id === requested })
    if (!found) return "service not found"
    editingServiceId = ""
    showingWidgetSettings = false
    selectedServiceId = requested
    expandedServiceId = requested
    if (!opened) open()
    Qt.callLater(function() { ensureServiceVisible(requested) })
    return "ok"
  }
  function openServiceDetails(serviceId) {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applyServiceDetails === "function") return target.applyServiceDetails(serviceId)
    return applyServiceDetails(serviceId)
  }
  function focusedDetailsReady(serviceId) {
    var target = focusedPanelInstance()
    return !!target && target.opened === true && target.showingWidgetSettings !== true
      && target.statusIndicatorVisible !== true && target.expandedServiceId === String(serviceId)
      && (typeof target.serviceIsVisible !== "function" || target.serviceIsVisible(serviceId))
  }
  function applyServiceEditor(serviceId) {
    var requested = String(serviceId || "")
    if (!services.some(function(entry) { return entry.id === requested })) return "service not found"
    showingWidgetSettings = false
    expandedServiceId = ""
    selectedServiceId = requested
    editingServiceId = requested
    popupScroll.contentY = 0
    refreshCatalog()
    if (!opened) open()
    return "ok"
  }
  function openServiceEditor(serviceId) {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applyServiceEditor === "function") return target.applyServiceEditor(serviceId)
    return applyServiceEditor(serviceId)
  }
  function focusedEditorReady(serviceId) {
    var target = focusedPanelInstance()
    return !!target && target.opened === true && target.showingWidgetSettings !== true
      && target.statusIndicatorVisible !== true && target.editingServiceId === String(serviceId)
  }
  function applyFiltersExpanded(expanded) {
    editingServiceId = ""
    showingWidgetSettings = false
    serviceFiltersExpanded = expanded === true
    if (!opened) open()
    return "ok"
  }
  function setFiltersExpanded(expanded) {
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applyFiltersExpanded === "function") return target.applyFiltersExpanded(expanded)
    return applyFiltersExpanded(expanded)
  }
  function focusedFiltersExpanded() {
    var target = focusedPanelInstance()
    return !!target && target.opened === true && target.serviceFiltersExpanded === true
  }
  function closeFocused() {
    var target = focusedPanelInstance()
    if (target && typeof target.close === "function") target.close()
    return "ok"
  }
  function focusedPanelClosed() {
    var target = focusedPanelInstance()
    return !target || target.opened !== true
  }
  function applySettingsPage(requested) {
    requested = String(requested || "general")
    editingServiceId = ""
    settingsPage = requested
    showingWidgetSettings = true
    if (!opened) open()
    return "ok"
  }
  function openSettings(page) {
    var requested = String(page || "general")
    if (["general", "appearance", "services", "performance", "discovery", "packages"].indexOf(requested) < 0) return "invalid page"
    var target = focusedPanelInstance()
    if (target && target !== root && typeof target.applySettingsPage === "function") return target.applySettingsPage(requested)
    return applySettingsPage(requested)
  }
  function focusedSettingsReady(page) {
    var target = focusedPanelInstance()
    return !!target && target.opened === true && target.showingWidgetSettings === true
      && target.settingsPage === String(page) && target.settingsSurfaceLoaded === true
      && target.settingsIndicatorVisible !== true
  }
  function reloadDurableSettings() { settingsStore.load(settings) }
  function reloadIfSharedSettingsAdvanced() {
    if (!p2pService || !durableSettingsLoaded || settingsStore.busy) return false
    var localRevision = Number(durableSettings._p2pRevision) || 0
    if (Number(p2pService.durableSettingsRevision) <= localRevision) return false
    reloadDurableSettings()
    return true
  }
  function reloadSettingsAcrossInstances() {
    var widgets = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root]
    if (!widgets || !widgets.length) widgets = [root]
    for (var index = 0; index < widgets.length; index++) {
      var widget = widgets[index]
      if (widget && typeof widget.reloadDurableSettings === "function") widget.reloadDurableSettings()
    }
    return "ok"
  }
  function focusedSettingsSnapshot() {
    var target = focusedPanelInstance()
    return JSON.stringify(target && target.durableSettingsLoaded ? target.durableSettings : {})
  }
  function labelFor(entry) { var values = setting("serviceLabels", {}) || {}; return values[entry.id] || entry.name }
  function filterByBackend(backend) {
    var requested = String(backend || "").trim().toLowerCase()
    backendFilter = backendFilter === requested ? "" : requested
    selectedServiceId = ""
  }
  function iconFor(entry) { var values = setting("serviceIcons", {}) || {}; return values[entry.id] || entry.icon }
  function categorySummaries() { return Model.categorySummaries(services, setting("categoryIcons", {}) || {}, false, false) }
  function saveCategoryIcon(category, icon) {
    persistKeepingOpen({categoryIcons:Model.categoryIconMap(setting("categoryIcons", {}) || {}, category, icon)})
  }
  function consoleUrl(entry) {
    if (!entry) return ""
    var values = setting("serviceConsoleUrls", {}) || {}
    return values[entry.id] !== undefined ? String(values[entry.id]) : String(entry.defaultWeb || "")
  }
  function hasConsole(entry) { return !!entry && (Model.safeHttpUrl(consoleUrl(entry)) !== "" || entry.hasWeb === true) }
  function saveConsoleUrl(id, value) {
    var update = Model.consoleUrlUpdate(value)
    if (!update.valid) {
      errorText = "Console URL must begin with http:// or https://"
      return
    }
    errorText = ""
    persistServiceMap("serviceConsoleUrls", id, update.url, true)
  }
  function openConsole(entry) {
    if (!entry) return
    var values = setting("serviceConsoleUrls", {}) || {}
    var configured = values[entry.id] !== undefined ? Model.safeHttpUrl(values[entry.id]) : ""
    var discovered = Model.safeHttpUrl(consoleUrl(entry))
    if (!serviceActions.openConsole(entry, configured || discovered)) errorText = "No valid console URL is configured"
  }
  function openLogs(entry) { serviceActions.openLogs(entry) }
  function copyDiagnostics(entry) { serviceActions.copyDiagnostics(entry, entry ? labelFor(entry) : "Service") }
  function installService(entry) { serviceActions.install(entry) }
  function catalogEntry(id) { return catalogIndexes.byId[id] || null }
  function canUninstall(entry) {
    var catalog = entry ? catalogEntry(entry.id) : null
    return !!catalog && catalog.installedPackages && catalog.installedPackages.length > 0
  }
  function requestUninstall(entry) {
    if (!entry || !canUninstall(entry)) return
    if (entry.active) { errorText = "Stop " + labelFor(entry) + " before uninstalling it."; return }
    uninstallConfirm.selectedIndex = 1
    confirmationState.requestUninstall(entry)
  }
  function cancelUninstall() { confirmationState.cancelUninstall() }
  function confirmUninstall() { confirmationState.confirmUninstall() }
  function requestRestore(entry, backupName) { if (confirmationState.requestRestore(entry, backupName)) restoreConfirm.selectedIndex = 1 }
  function cancelRestore() { confirmationState.cancelRestore() }
  function confirmRestore() { confirmationState.confirmRestore() }
  function saveCustomServices(raw) {
    var parsed = Model.parseCustomServices(raw)
    if (!parsed.valid) { errorText = "Custom services must be a valid JSON array"; return }
    errorText = ""
    persistKeepingOpen({customServices: parsed.services}); refresh(true, true, true)
  }
  function startSettingsTransfer(mode) {
    if (settingsPersistenceRunning) return false
    if (!settingsTransferController.request(mode)) return false
    settingsTransferDisplayMode = mode
    settingsTransferLoadingState.start()
    return true
  }
  function exportSettings() { return startSettingsTransfer("export") }
  function importSettings() { return startSettingsTransfer("import") }
  function undoSettings() { return startSettingsTransfer("undo") }
  function settingsTransferLabel() {
    if (settingsTransferDisplayMode === "import") return "IMPORTING SETTINGS"
    if (settingsTransferDisplayMode === "undo") return "RESTORING SETTINGS"
    return "EXPORTING SETTINGS"
  }
  function serviceActionLabel(id) {
    if (pendingService !== id) return ""
    if (pendingAction === "start") return "STARTING"
    if (pendingAction === "stop") return "STOPPING"
    if (pendingAction === "restart") return "RESTARTING"
    if (pendingAction === "config") return "OPENING CONFIG"
    return "WORKING"
  }
  function updateTrafficRates(next) {
    var now = Date.now(), history = {}, rates = {}
    for (var index = 0; index < next.length; index++) {
      var entry = next[index], previous = trafficHistory[entry.id]
      if (entry.trafficAvailable) {
        history[entry.id] = {rx: Number(entry.rxBytes) || 0, tx: Number(entry.txBytes) || 0, at: now}
        if (previous && now > previous.at && history[entry.id].rx >= previous.rx && history[entry.id].tx >= previous.tx) {
          var seconds = (now - previous.at) / 1000
          var rx = (history[entry.id].rx - previous.rx) / seconds
          var tx = (history[entry.id].tx - previous.tx) / seconds
          var window = Math.max(1, Number(setting("trafficSmoothingSeconds", 3)) || 3)
          var alpha = Math.min(1, seconds / window)
          rates[entry.id] = Model.smoothTrafficRate(trafficRates[entry.id], {rx:rx,tx:tx}, alpha, Number(setting("trafficMinimumBytesPerSecond", 1024)) || 0)
        }
      }
    }
    trafficHistory = history
    trafficRates = rates
  }
  function serviceShowsStopped(id) { var values = setting("serviceShowStopped", {}) || {}; return values[id] !== undefined ? values[id] === true : showStopped }
  function persistServiceMap(key, id, value, removeEmpty) {
    var source = {}; source[key] = setting(key, {})
    persistKeepingOpen(Model.serviceMapPatch(source, key, id, value, removeEmpty))
  }
  function persistKeepingOpen(values) {
    privacyToggleInProgress = true
    privacyToggleGuard.restart()
    persist(values)
    Qt.callLater(function() { if (!root.opened) root.open() })
  }
  function commitSettings(values, refreshAfterCommit) {
    var organizationChange = Model.organizationChanged(values)
    var entry = {id:moduleName}, source = durableSettingsLoaded ? durableSettings : settings
    for (var key in source) if (key !== "id") entry[key] = source[key]
    for (var changed in values) entry[changed] = values[changed]
    entry._p2pSettingsVersion = 1
    entry._p2pRevision = Math.max(0, Number(entry._p2pRevision) || 0) + 1
    entry._p2pUpdatedAt = Date.now()
    settings = entry
    writeDurableSettings(entry, values)
    if (organizationChange) organizationState.invalidate(values)
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function") bar.shell.updateEntryInline(moduleName, entry)
    if (refreshAfterCommit === true && setting("refreshAfterSettings", true) === true) refresh()
  }
  function persistQuietly(values) { commitSettings(values, false) }
  function moveService(id, delta) {
    var order = services.map(function(entry) { return entry.id })
    var index = order.indexOf(id), target = index + delta
    if (index < 0 || target < 0 || target >= order.length) return
    var swap = order[target]; order[target] = order[index]; order[index] = swap
    persistKeepingOpen({serviceOrder: order})
  }
  function resetService(id) {
    var source = {}, keys = ["serviceLabels", "serviceIcons", "serviceShowStopped", "serviceConsoleUrls", "serviceNotificationPolicies"]
    for (var index = 0; index < keys.length; index++) source[keys[index]] = setting(keys[index], {})
    source.favoriteServices = setting("favoriteServices", [])
    persistKeepingOpen(Model.resetServicePatch(source, id))
  }
  function persist(values) {
    commitSettings(values, true)
  }
  function togglePrivacyFilter() {
    privacyToggleInProgress = true
    privacyToggleGuard.restart()
    privacyFilterOverride = !privacyFilter
    refresh()
    Qt.callLater(function() { if (!root.opened) root.open() })
  }
  function persistPrivacyFilter() {
    if (privacyFilterOverride === undefined) return
    var value = privacyFilterOverride === true
    commitSettings({privacyFilter:value}, false)
    privacyFilterOverride = undefined
  }
  function refresh(forceCatalog, fullContainers, bypassCache) {
    if (forceCatalog === true) refreshCatalog()
    if (fullContainers === true) fullContainerScanPending = true
    if (!services.length) startStatusLoading()
    if (p2pService && typeof p2pService.requestRefresh === "function") {
      syncService()
      var sharedFullScan = fullContainerScanPending
      fullContainerScanPending = false
      refreshStartedAt = Date.now()
      lastScanKind = sharedFullScan ? "Full shared reconciliation" : "Fast shared running-only scan"
      p2pService.requestRefresh(sharedFullScan, bypassCache === true)
      return
    }
    var fallbackFullScan = fullContainerScanPending
    fullContainerScanPending = false
    refreshStartedAt = Date.now()
    lastScanKind = fallbackFullScan ? "Full reconciliation" : "Fast running-only scan"
    refreshController.request([helper, "status", privacyFilter ? "private" : "unsafe", String(setting("consoleHost", "")).trim(), setting("showTrafficStats", true) === true ? "stats" : "no-stats"], fallbackFullScan, bypassCache)
  }
  function refreshCatalog() {
    if (!catalogController.request()) return false
    catalogLoadingState.start()
    return true
  }
  function finishCatalogLoading() { catalogLoadingState.finish() }
  function startStatusLoading() {
    statusLoading = true
    statusLoadingState.start()
  }
  function finishStatusLoading() {
    statusLoading = false
    statusLoadingState.finish()
  }
  function startSettingsLoading() {
    if (!showingWidgetSettings) {
      settingsLoadingState.cancel()
      return
    }
    settingsLoadingState.start()
  }
  function finishSettingsLoading() { settingsLoadingState.finish() }
  function startCatalogTracking() { catalogBurstRemaining = 8; catalogBurstTimer.restart() }
  function mergeServiceStatus(next, fullScan) {
    services = Model.mergeServiceStatus(services, next, fullScan)
  }
  function applyStatusRefresh(next, fullScan) {
    var previousServices = services.slice()
    captureSortOrder()
    updateTrafficRates(next)
    mergeServiceStatus(next, fullScan)
    handleServiceTransitions(previousServices, services)
    lastRefreshDurationMs = refreshStartedAt > 0 ? Math.max(0, Date.now() - refreshStartedAt) : 0
    lastSuccessfulRefreshAt = Date.now()
    consecutiveRefreshFailures = 0
    errorText = ""
    finishStatusLoading()
  }
  function transitionNotificationAllowed(id, kind) {
    var result = Model.transitionCooldown(notificationLastAt, id, kind, Date.now(), setting("notificationCooldownSeconds", 30))
    notificationLastAt = result.timestamps
    return result.allowed
  }
  function transitionNotificationEligible(change, entry, now) {
    if (!entry || !change) return false
    if (change.kind === "stopped") return setting("notifyUnexpectedStops", false) === true && now > Number(controlledUntil[change.id] || 0)
    if (change.kind === "recovered") return setting("notifyRecovery", false) === true
    if (change.kind === "unhealthy") return setting("notifyUnhealthy", true) === true
    if (change.kind === "restarts") return setting("notifyRestartEvents", true) === true
    return false
  }
  function handleServiceTransitions(previous, next) {
    if (!previous.length) return
    var changes = Model.serviceTransitions(previous, next, Number(setting("restartWarningThreshold", 3)) || 3)
    var eligible = []
    for (var index = 0; index < changes.length; index++) {
      var change = changes[index], entry = next.find(function(item) { return item.id === change.id })
      var now = Date.now()
      if (!transitionNotificationEligible(change, entry, now) || !transitionNotificationAllowed(change.id, change.kind)) continue
      eligible.push(Object.assign({}, change, {label:labelFor(entry)}))
    }
    Model.transitionNotifications(eligible).forEach(function(message) {
      notify(message.title, message.body)
      if (setting("enableEventJournal", false) === true) journal.record(message.kind, message.count)
    })
  }
  function recordRefreshFailure(detail) {
    var failure = Model.refreshFailureState(consecutiveRefreshFailures, detail)
    consecutiveRefreshFailures = failure.failures
    errorText = failure.error
    finishStatusLoading()
  }
  function refreshHealthText() {
    return Model.refreshHealthText({lastSuccessfulAt:lastSuccessfulRefreshAt,lastScanKind:lastScanKind,
      durationMs:lastRefreshDurationMs,staleSeconds:setting("staleWarningSeconds", 60),
      diagnostics:helperDiagnostics.length,failures:consecutiveRefreshFailures}, Date.now())
  }
  function flushDeferredRefresh() {
    deferredRefresh.flush()
  }
  function notify(title, body) {
    Quickshell.execDetached(["omarchy", "notification", "send", "--app-name", "P2P Services", "--urgency", "normal", String(title), String(body)])
  }
  function copySupportReport() {
    var telemetry = p2pService && typeof p2pService.monitoringTelemetry === "function" ? p2pService.monitoringTelemetry() : {}
    var monitoring = {
      watcherHealth:String(telemetry.watcherHealth || "unavailable"), watcherCode:String(telemetry.watcherCode || "unavailable"),
      settingsWatcherHealth:String(telemetry.settingsWatcherHealth || "unavailable"), settingsWatcherCode:String(telemetry.settingsWatcherCode || "unavailable"),
      lastRefreshAgeSeconds:Number(telemetry.lastRefreshAgeSeconds) || 0, consecutiveRefreshFailures:consecutiveRefreshFailures
    }
    Quickshell.execDetached([helper, "copy-support-report", JSON.stringify(monitoring)])
    notify("P2P support report", "Copied a privacy-filtered plugin report to the clipboard")
  }
  function clearEventJournal() { journal.clear() }
  function actionResult(exitCode, detail, serviceName, requestedAction) {
    var name = serviceName || pendingServiceName || pendingService || "Service"
    var action = requestedAction || pendingAction || "update"
    var message = Model.actionNotification(name, action, exitCode, detail)
    notify(message.title, message.body)
  }
  function act(entry, action) {
    if (!entry || actionRunner.running || (entry.controllable === false && ["start","stop","restart","config"].indexOf(action) >= 0)) return
    serviceActions.control(entry, action)
  }
  function tooltip() {
    var status = services.length ? activeCount + "/" + services.length + " active\nPrivacy filter: " + (privacyFilter ? "on" : "off") : "No supported services detected"
    var presentation = String(setting("barPresentation", "active"))
    if (presentation === "category-active" || presentation === "category-active-total") {
      var categories = Model.categorySummaries(services, setting("categoryIcons", {}) || {}, presentation === "category-active-total", setting("hideZeroCount", false) === true)
      if (categories.length) status += "\nGroups: " + categories.map(function(row) { return row.text }).join("  ")
    }
    if (consecutiveRefreshFailures > 0) status += "\nRefresh degraded: showing last successful data"
    return "P2P Services · " + status + "\nMiddle: settings · Right: full refresh"
  }
  function handleBarPress(mouseButton) {
    if (mouseButton === Qt.MiddleButton) {
      editingServiceId = ""
      showingWidgetSettings = true
      if (!opened) open()
    } else if (mouseButton === Qt.RightButton) {
      refresh(true, true, true)
    } else {
      toggle()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onOpenedChanged: {
    if (opened) {
      if (setting("refreshOnOpen", true) === true) refresh(false, false)
    } else {
      confirmationState.cancelAll()
      expandedServiceId = ""
      serviceFiltersExpanded = false
      settingsPage = "general"
      if (privacyToggleInProgress) Qt.callLater(function() { root.open() })
      else persistPrivacyFilter()
    }
  }

  WidgetButton {
    id: button
    property real labelWidth: implicitWidth
    anchors.fill: parent
    bar: root.bar
    text: setting("showCount", true) ? root.barText() : String(setting("widgetIcon", "󰒍"))
    fontSize: Number(root.setting("barFontSize", 14))
    horizontalMargin: Number(root.setting("barHorizontalMargin", 8))
    verticalPadding: Number(root.setting("barVerticalPadding", 6))
    fixedWidth: Number(root.setting("barFixedWidth", 0)) > 0 ? Number(root.setting("barFixedWidth", 0)) : -1
    textRotation: root.barRotation()
    foreground: root.themeColor(String(root.setting("barForegroundColorRole", "foreground")), root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: root.tooltip()
    active: root.opened
    useActiveColor: root.activeCount > 0
    activeColor: root.errorCount > 0 || root.consecutiveRefreshFailures > 0
      ? root.themeColor(String(root.setting("errorColorRole", "urgent")), Color.urgent)
      : root.themeColor(String(root.setting("barActiveColorRole", "accent")), Color.accent)
    dimmed: root.setting("barDimWhenIdle", false) === true && root.activeCount === 0 && !root.opened
    onPressed: function(mouseButton) { root.handleBarPress(mouseButton) }
  }

  IpcHandler {
    target: root.moduleName
    function captureContract(): string { return root.captureContractVersion() }
    function open(): string { return root.openMainView() }
    function close(): string { return root.closeFocused() }
    function mainReady(layout: string, density: string): string { return root.focusedMainReady(layout, density) ? "true" : "false" }
    function openDetails(serviceId: string): string { return root.openServiceDetails(serviceId) }
    function detailsReady(serviceId: string): string { return root.focusedDetailsReady(serviceId) ? "true" : "false" }
    function openEditor(serviceId: string): string { return root.openServiceEditor(serviceId) }
    function editorReady(serviceId: string): string { return root.focusedEditorReady(serviceId) ? "true" : "false" }
    function showFilters(): string { return root.setFiltersExpanded(true) }
    function filtersReady(): string { return root.focusedFiltersExpanded() ? "true" : "false" }
    function panelClosed(): string { return root.focusedPanelClosed() ? "true" : "false" }
    function openSettings(page: string): string { return root.openSettings(page) }
    function scrollSettings(position: string): string { return root.setSettingsScroll(position) }
    function settingsReady(page: string): string { return root.focusedSettingsReady(page) ? "true" : "false" }
    function reloadSettings(): string { return root.reloadSettingsAcrossInstances() }
    function settingsSnapshot(): string { return root.focusedSettingsSnapshot() }
    function privacyEnabled(): string { return root.privacyFilter ? "true" : "false" }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(root.desiredPanelWidth)
    contentHeight: fittedContentHeight(root.configuredPanelHeight, root.configuredPanelHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.closeCurrentLayer()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0 && root.editingServiceId === "" && !root.showingWidgetSettings) root.moveServiceSelection(dy)
      }
      onActivateRequested: {
        if (root.editingServiceId === "" && !root.showingWidgetSettings) root.activateServiceSelection()
      }
      onTextKey: function(text) {
        if ((text === "r" || text === "R") && !serviceSearch.activeFocus) root.refresh(false, true, true)
        else if (text === "/" && !root.showingWidgetSettings) serviceSearch.forceActiveFocus()
        else if ((text === "s" || text === "S") && !serviceSearch.activeFocus) { root.editingServiceId = ""; root.showingWidgetSettings = true }
        else if (root.showingWidgetSettings && "1234".indexOf(text) >= 0) root.showSettingsPage(["general", "performance", "discovery", "packages"][Number(text) - 1])
      }
      onTabRequested: function(direction) { if (bar && typeof bar.switchPanelFrom === "function") bar.switchPanelFrom(root, direction) }

      ColumnLayout {
        id: popupLayout
        anchors.fill: parent
        spacing: Style.spacing.md

        P2PHeader {
          visible: root.editingServiceId === "" && !root.showingWidgetSettings
          controller: root
          Layout.fillWidth: true
        }

        P2PSettingsNavigation {
          visible: root.showingWidgetSettings
          controller: root
          Layout.fillWidth: true
        }

        PanelSeparator {
          visible: root.editingServiceId === ""
          Layout.fillWidth: true
          foreground: root.bar ? root.bar.foreground : Color.popups.text
        }

        Flickable {
        id: popupScroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Style.space(180)
        contentWidth: content.width
        contentHeight: content.implicitHeight
        clip: true
        pixelAligned: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        onMovementStarted: root.captureSortOrder()
        onMovementEnded: root.flushDeferredRefresh()
        ScrollBar.vertical: ScrollBar { id: popupScrollBar; policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: content
          width: Math.max(1, popupScroll.width - root.scrollbarGutter)
          spacing: Style.spacing.md

        RowLayout {
          objectName: "serviceSearchRow"
          visible: root.editingServiceId === "" && !root.showingWidgetSettings && root.services.length > 0
          Layout.fillWidth: true
          TextField {
            id: serviceSearch
            Layout.fillWidth: true
            placeholderText: "Search services, categories, backends, or units"
            text: root.searchQuery
            foreground: Color.popups.text
            accent: Color.bar.active
            font.family: Style.font.family
            onTextChanged: root.searchQuery = text
          }
          Button {
            iconText: "󰅖"
            tooltipText: "Clear search"
            visible: root.searchQuery !== ""
            horizontalPadding: Style.spacing.controlGap
            onClicked: { root.searchQuery = ""; serviceSearch.forceActiveFocus() }
          }
          Button {
            objectName: "serviceFiltersToggle"
            iconText: "󰈲"
            tooltipText: root.serviceFiltersExpanded ? "Hide service filters" : "Show service filters"
            active: root.serviceFiltersExpanded || root.serviceFilter !== "all" || root.backendFilter !== ""
            selected: active
            horizontalPadding: Style.spacing.controlGap
            onClicked: root.serviceFiltersExpanded = !root.serviceFiltersExpanded
          }
        }

        P2PSavedViews {
          visible: root.editingServiceId === "" && !root.showingWidgetSettings && (root.setting("savedViews", []) || []).length > 0
          controller: root
          Layout.fillWidth: true
        }

        P2PFilterBar {
          id: serviceFilterBar
          objectName: "serviceFiltersRow"
          visible: root.editingServiceId === "" && !root.showingWidgetSettings && root.services.length > 0 && root.serviceFiltersExpanded
          controller: root
          Layout.fillWidth: true
        }

        P2PMessageSurface {
          visible: root.visibleErrorText !== ""
          message: root.visibleErrorText
          icon: "󰅙"
          tone: Color.urgent
          actionText: "Diagnostics"
          onActionRequested: root.showSettingsSection("performance", "diagnostics")
        }

        P2PLoadingIndicator {
          id: serviceLoadingIndicator
          objectName: "serviceLoadingIndicator"
          running: root.setting("showLoadingIndicators", true) === true && root.statusIndicatorVisible && root.services.length === 0 && root.visibleErrorText === "" && root.editingServiceId === "" && !root.showingWidgetSettings
          animationEnabled: root.opened
          label: "DISCOVERING P2P SERVICES"
          style: String(root.setting("loadingIndicatorStyle", "spinner"))
          glyph: String(root.setting("loadingIndicatorGlyph", ">"))
          speed: Number(root.setting("loadingIndicatorSpeed", 140)) || 140
          tone: root.themeColor("accent", Color.accent)
        }

        P2PMessageSurface {
          visible: root.editingServiceId === "" && !root.showingWidgetSettings && root.visibleServices.length === 0 && root.visibleErrorText === "" && (!root.statusIndicatorVisible || root.setting("showLoadingIndicators", true) !== true)
          message: root.services.length
            ? (root.searchQuery
                ? "No " + (root.serviceFilter === "all" ? "services" : root.serviceFilter + " services") + " match “" + root.searchQuery + "”" + (root.backendFilter ? " using the " + root.backendFilter + " backend." : ".")
                : (root.backendFilter
                    ? "No " + (root.serviceFilter === "all" ? "services" : root.serviceFilter + " services") + " use the " + root.backendFilter + " backend."
                    : "No services match the “" + root.serviceFilter + "” view."))
            : "No supported P2P services detected."
          icon: root.services.length ? "󰍉" : "󰒍"
          tone: Color.muted
          actionText: root.services.length === 0 ? "Configure discovery" : ""
          onActionRequested: root.showSettingsSection("discovery", "custom-services")
        }

        P2PServiceList { id: serviceList; controller: root; Layout.fillWidth: true }

        Loader {
          id: settingsPageLoader
          active: root.showingWidgetSettings
          asynchronous: true
          visible: active && !root.settingsIndicatorVisible
          Layout.fillWidth: true
          source: root.settingsSurfaceSource
          sourceComponent: String(root.settingsSurfaceSource) === "" ? defaultSettingsSurface : null
          onLoaded: { root.settingsErrorText = ""; root.finishSettingsLoading(); Qt.callLater(root.scrollToSettingsSection) }
          onStatusChanged: if (status === Loader.Error) {
            settingsLoadingState.cancel()
            root.settingsErrorText = "Unable to load P2P settings interface"
          }
        }
        Component { id: defaultSettingsSurface; P2PSettingsPanel { controller: root } }
        P2PLoadingIndicator {
          objectName: "settingsLoadingIndicator"
          running: root.settingsIndicatorVisible
          animationEnabled: root.opened
          label: "LOADING SETTINGS MODULES"
          style: String(root.setting("loadingIndicatorStyle", "spinner"))
          glyph: String(root.setting("loadingIndicatorGlyph", ">"))
          speed: Number(root.setting("loadingIndicatorSpeed", 140)) || 140
          tone: root.themeColor("accent", Color.accent)
        }

        P2PServiceEditor {
          controller: root
          visible: root.editingServiceId !== ""
          Layout.fillWidth: true
        }
      }
      }

        PanelSeparator {
          visible: root.editingServiceId === "" && (root.showingWidgetSettings || root.services.length > 0)
          Layout.fillWidth: true
          foreground: root.bar ? root.bar.foreground : Color.popups.text
        }
        Text {
          visible: root.editingServiceId === "" && !root.showingWidgetSettings && root.services.length > 0
          Layout.fillWidth: true
          text: popupLayout.width < Style.space(440)
            ? "j/k move · enter details · r refresh · s settings\nMiddle customize · right details"
            : "j/k navigate · enter details · r refresh · s settings\nCard middle: customize · right: details"
          textFormat: Text.PlainText
          color: Color.muted
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        P2PSettingsReset {
          visible: root.showingWidgetSettings
          controller: root
          Layout.fillWidth: true
        }
      }
    }
  }


  Timer { interval: root.pollIntervalMilliseconds; running: true; repeat: true; onTriggered: { if (!popupScroll.moving) root.refresh(false, false) } }
  Timer {
    interval: Math.max(60, Number(root.setting("loadingIndicatorSpeed", 140)) || 140)
    running: root.statusLoading && root.setting("showLoadingIndicators", true) === true
    repeat: true
    onTriggered: root.barLoadingFrameIndex += 1
  }
  P2POrganizationState { id: organizationState; onStabilityStopRequested: sortStabilityTimer.stop() }
  P2PEventJournal { id: journal; helper: root.helper; onFailed: root.errorText = "Unable to update the local event journal" }
  P2PDeferredRefresh { id: deferredRefresh; onApplyRequested: function(services, fullScan) { root.applyStatusRefresh(services, fullScan) } }
  P2PServiceConfirmationController {
    id: confirmationState
    onUninstallConfirmed: function(entry) { serviceActions.uninstall(entry, root.labelFor(entry)) }
    onRestoreConfirmed: function(entry, backupName) { serviceActions.restore(entry, backupName, root.labelFor(entry)) }
  }
  Timer { id: sortStabilityTimer; interval: 3000; onTriggered: organizationState.expire() }
  Timer {
    interval: root.reconcileSeconds * 1000
    running: true
    repeat: true
    onTriggered: {
      if (popupScroll.moving) root.fullContainerScanPending = true
      else root.refresh(false, true)
    }
  }
  P2PMinimumLoadingState { id: statusLoadingState; minimumDuration: 400; presentationEnabled: root.setting("showLoadingIndicators", true) === true }
  P2PMinimumLoadingState { id: settingsLoadingState; minimumDuration: 250; presentationEnabled: root.setting("showLoadingIndicators", true) === true }
  P2PMinimumLoadingState { id: catalogLoadingState; minimumDuration: 600; presentationEnabled: root.setting("showLoadingIndicators", true) === true }
  P2PMinimumLoadingState { id: settingsTransferLoadingState; minimumDuration: 400; presentationEnabled: root.setting("showLoadingIndicators", true) === true }
  Timer { id: settingsSavedClear; interval: 1500; onTriggered: if (root.settingsSaveStatus === "saved") root.settingsSaveStatus = "" }
  Timer { interval: 300000; running: root.opened && root.showingWidgetSettings && root.settingsPage === "packages"; repeat: true; onTriggered: root.refreshCatalog() }
  Timer {
    id: catalogBurstTimer
    interval: 15000
    repeat: true
    onTriggered: {
      if (!popupScroll.moving) {
        root.refreshCatalog(); root.fullContainerScanPending = true
        root.catalogBurstRemaining--
        if (root.catalogBurstRemaining <= 0) stop()
      }
    }
  }
  Timer {
    id: privacyToggleGuard
    interval: 500
    onTriggered: {
      root.privacyToggleInProgress = false
      if (!root.opened) root.open()
    }
  }

  P2PRefreshController {
    id: refreshController
    onSucceeded: function(payload, fullScan) {
      if (!payload) { root.recordRefreshFailure(""); return }
      try {
        var parsed = JSON.parse(payload)
        if (!parsed || !Array.isArray(parsed.services)) throw new Error("status response has no service list")
        root.helperDiagnostics = Array.isArray(parsed.diagnostics) ? parsed.diagnostics : []
        deferredRefresh.receive(parsed.services, fullScan, popupScroll.moving)
      } catch (error) { root.recordRefreshFailure(error) }
    }
    onFailed: function(exitCode) { root.recordRefreshFailure("Helper exited with " + exitCode) }
  }
  P2PSettingsStore {
    id: settingsStore
    helper: root.helper
    moduleName: root.moduleName
    onReconciled: function(merged) {
      root.settings = merged
      if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") root.bar.shell.updateEntryInline(root.moduleName, merged)
      root.applyInitialView()
      Qt.callLater(root.reloadIfSharedSettingsAdvanced)
    }
    onUpdated: function(merged) {
      root.settings = merged
      if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") root.bar.shell.updateEntryInline(root.moduleName, merged)
      if (root.setting("persistCollapsedGroups", true) === true) root.collapsedServiceGroups = root.setting("collapsedServiceGroups", {}) || {}
    }
    onSaved: {
      if (root.settingsSaveStatus === "saving") { root.settingsSaveStatus = "saved"; settingsSavedClear.restart() }
      Qt.callLater(root.reloadIfSharedSettingsAdvanced)
    }
    onLoadFailed: root.errorText = "Unable to load saved P2P settings; using shell settings"
    onSaveFailed: root.restoreFailedSettings()
  }
  P2PServiceActions {
    id: serviceActions
    helper: root.helper
    privacyFiltered: root.privacyFilter
    autoStartAfterInstall: root.setting("autoStartAfterInstall", false) === true
    backupRetention: Number(root.setting("backupRetention", 10)) || 10
    onNotifyRequested: function(title, body) { root.notify(title, body) }
    onCatalogTrackingRequested: root.startCatalogTracking()
    onActionRequested: function(entry, action, command) {
      if (!actionRunner.request(entry, action, command)) return
      root.errorText = ""
      root.pendingService = entry.id
      root.pendingServiceName = root.labelFor(entry)
      root.pendingAction = action
      var recent = Object.assign({}, root.controlledUntil); recent[entry.id] = Date.now() + 10000; root.controlledUntil = recent
    }
  }
  P2PSettingsTransferController {
    id: settingsTransferController
    helper: root.helper
    onFailed: function(mode, _exitCode, detail) { settingsTransferLoadingState.finish(); root.errorText = "Settings " + mode + " failed" + (detail ? ": " + detail : "") }
    onSucceeded: function(mode, payload) { settingsTransferLoadingState.finish(); settingsTransferResult.apply(mode, payload) }
  }
  P2PSettingsTransferResult { id: settingsTransferResult; controller: root; moduleName: root.moduleName; onErrorRequested: function(message) { root.errorText = message } }
  Connections {
    target: root.p2pService
    function onDurableSettingsRevisionChanged() {
      root.reloadIfSharedSettingsAdvanced()
    }
    function onRefreshSerialChanged() {
      if (!root.p2pService || !Array.isArray(root.p2pService.services)) return
      deferredRefresh.receive(root.p2pService.services, root.p2pService.lastFullScan, popupScroll.moving)
      root.helperDiagnostics = root.p2pService.diagnostics || []
      root.lastRefreshDurationMs = root.p2pService.lastDurationMs
    }
    function onRefreshErrorChanged() { if (root.p2pService && root.p2pService.refreshError) root.recordRefreshFailure(root.p2pService.refreshError) }
  }
  P2PCatalogController {
    id: catalogController
    helper: root.helper
    onUpdated: function(entries) { root.serviceCatalog = entries; root.catalogErrorText = ""; root.finishCatalogLoading() }
    onFailed: function(_exitCode) { root.catalogErrorText = "Service catalog refresh failed"; root.finishCatalogLoading() }
  }
  P2PActionRunner {
    id: actionRunner
    onActionFinished: function(entry, action, exitCode, detail) {
      if (entry && root.shouldNotifyService(entry.id, exitCode)) root.actionResult(exitCode, detail, root.labelFor(entry), action)
      if (root.setting("enableEventJournal", false) === true) journal.record(exitCode === 0 ? "action-success" : "action-failure", 1)
      root.pendingService = ""
      root.pendingServiceName = ""
      root.pendingAction = ""
      refreshDelay.restart()
    }
  }
  Timer { id: refreshDelay; interval: 800; onTriggered: if (root.setting("refreshAfterActions", true) === true) root.refresh(false, true, true) }
  ConfirmDialog {
    id: uninstallConfirm
    parent: keyCatcher
    anchors.fill: parent
    opened: root.uninstallConfirmOpen
    z: 100
    message: "Uninstall " + (root.uninstallTarget ? root.labelFor(root.uninstallTarget) : "this service") + "? Installed allowlisted packages will be removed through Omarchy. Configuration will be copied to the P2P Services user data directory first. Containers, images, volumes, and manual installs are not removed."
    confirmText: "Uninstall"
    onCanceled: root.cancelUninstall()
    onConfirmed: root.confirmUninstall()
  }
  ConfirmDialog {
    id: restoreConfirm
    parent: keyCatcher
    anchors.fill: parent
    opened: root.restoreConfirmOpen
    z: 100
    message: "Restore configuration backup " + root.restoreBackupName + " for " + (root.restoreTarget ? root.labelFor(root.restoreTarget) : "this service") + "? The current configuration is backed up first."
    confirmText: "Restore"
    onCanceled: root.cancelRestore()
    onConfirmed: root.confirmRestore()
  }
  onSettingsChanged: Qt.callLater(syncService)
  onP2pServiceChanged: Qt.callLater(syncService)
  onStatusLoadingChanged: if (statusLoading) barLoadingFrameIndex = 0
  onShowingWidgetSettingsChanged: startSettingsLoading()
  Component.onCompleted: { settingsStore.load(root.settings); journal.load(); Qt.callLater(syncService); root.refresh(false, true) }
}
