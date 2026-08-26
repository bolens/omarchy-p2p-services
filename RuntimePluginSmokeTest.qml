import Quickshell
import QtQuick
import "PathUtils.js" as PathUtils

ShellRoot {
  id: root
  property int updates: 0
  property int stage: 0
  property double settingsLoadDeadline: 0
  readonly property string fixtureHelper: PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/smoke-helper"))

  Service { id: sharedService; helper: root.fixtureHelper }

  QtObject {
    id: shellMock
    function serviceFor(id) { return id === "io.github.bolens.p2p-services" ? sharedService : null }
    function updateEntryInline(_id, _settings) { root.updates += 1 }
  }

  QtObject {
    id: barMock
    property bool routeToFocusedFixture: false
    property bool routeReloadFixture: false
    property var shell: shellMock
    property color barForeground: "#ffffff"
    property color foreground: "#ffffff"
    property color urgent: "#ff5555"
    property bool vertical: false
    property int barSize: 40
    property string position: "top"
    property var screen: null
    function switchPanelFrom(_owner, _direction) { return false }
    function findPanelWidget(_id) { return routeToFocusedFixture ? focusedWidgetFixture : widget }
    function moduleWidgets(_id) { return routeReloadFixture ? [reloadWidgetFixture] : [widget] }
  }

  QtObject {
    id: focusedWidgetFixture
    property string requestedPage: ""
    property bool opened: true
    property bool showingWidgetSettings: true
    property string settingsPage: requestedPage
    property bool settingsSurfaceLoaded: true
    property bool settingsIndicatorVisible: false
    property bool statusIndicatorVisible: false
    property string editingServiceId: ""
    property string expandedServiceId: ""
    property var services: [{id:"i2p"}]
    property bool durableSettingsLoaded: true
    property var durableSettings: ({privacyFilter:true,serviceLayout:"grid"})
    property int mainViewRequests: 0
    function applySettingsPage(page) { requestedPage = page; return "ok" }
    function applyMainView() { showingWidgetSettings = false; mainViewRequests += 1; return "ok" }
    function applyServiceDetails(id) { showingWidgetSettings = false; expandedServiceId = id; return "ok" }
    function setting(key, fallback) { var values = {serviceLayout:"grid",cardDensity:"compact"}; return values[key] === undefined ? fallback : values[key] }
    function close() { opened = false }
    function open() {}
  }

  QtObject {
    id: reloadWidgetFixture
    property int reloads: 0
    function reloadDurableSettings() { reloads += 1 }
  }

  BarWidget {
    id: widget
    bar: barMock
    helper: root.fixtureHelper
    settings: ({eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false})
  }

  Component.onCompleted: {
    if (widget.barText().indexOf("0") >= 0 || widget.barText().indexOf("⠋") < 0)
      throw new Error("initial bar loading state showed a zero count instead of a spinner")
  }

  Timer {
    interval: 350
    running: true
    repeat: true
    onTriggered: {
      if (root.stage === 0) {
      if (widget.moduleName !== "io.github.bolens.p2p-services" || widget.p2pService !== sharedService) throw new Error("plugin service wiring failed")
      if (!widget.durableSettingsLoaded || !Array.isArray(widget.services) || widget.barText() === "") throw new Error("plugin initial load failed")
      barMock.routeToFocusedFixture = true
      if (widget.openSettings("packages") !== "ok" || focusedWidgetFixture.requestedPage !== "packages" || widget.showingWidgetSettings)
        throw new Error("settings IPC did not route to the focused monitor instance")
      if (!widget.focusedSettingsReady("packages") || widget.focusedSettingsReady("general"))
        throw new Error("focused settings readiness did not identify the loaded page")
      if (widget.openMainView() !== "ok" || focusedWidgetFixture.showingWidgetSettings || focusedWidgetFixture.mainViewRequests !== 1)
        throw new Error("main view IPC did not route to the focused monitor instance")
      if (!widget.focusedMainReady("grid", "compact")) throw new Error("focused main view readiness failed")
      if (widget.openServiceDetails("i2p") !== "ok" || !widget.focusedDetailsReady("i2p")) throw new Error("focused details routing failed")
      if (widget.closeFocused() !== "ok" || !widget.focusedPanelClosed()) throw new Error("focused close routing failed")
      focusedWidgetFixture.opened = true
      var snapshot = JSON.parse(widget.focusedSettingsSnapshot())
      if (snapshot.privacyFilter !== true || snapshot.serviceLayout !== "grid") throw new Error("focused settings snapshot failed")
      barMock.routeToFocusedFixture = false
      barMock.routeReloadFixture = true
      if (widget.reloadSettingsAcrossInstances() !== "ok" || reloadWidgetFixture.reloads !== 1)
        throw new Error("durable settings reload was not broadcast to live instances")
      barMock.routeReloadFixture = false
      if (widget.statusLoading) throw new Error("initial service loading state did not settle")
      widget.services = [{id:"container",name:"Container",backend:"docker",active:true,hasError:false},{id:"unit",name:"Unit",backend:"systemd",active:true,hasError:false}]
      widget.filterByBackend("docker")
      if (widget.backendFilter !== "docker" || widget.searchQuery !== "" || widget.serviceFilter !== "all") throw new Error("backend pill filter state failed")
      if (widget.visibleServices.length !== 1 || widget.visibleServices[0].id !== "container") throw new Error("structured backend filter did not constrain services")
      widget.closeCurrentLayer()
      if (widget.backendFilter !== "") throw new Error("escape layer did not clear backend filter")
      widget.filterByBackend("docker")
      widget.filterByBackend("docker")
      if (widget.backendFilter !== "") throw new Error("backend pill filter did not toggle off")
      widget.services = []
      if (!widget.serviceLoadingVisible) throw new Error("fast service discovery did not retain a visible loading frame")
      widget.saveConsoleUrl("syncthing", "file:///tmp/ui")
      if (widget.errorText.indexOf("http://") < 0) throw new Error("widget console URL rejection failed")
      widget.saveConsoleUrl("syncthing", "https://sync.example.test")
      if (widget.errorText !== "") throw new Error("widget console URL acceptance failed")
      if (widget.settingsSaveStatus !== "saving") throw new Error("durable settings save status did not start")
      widget.settingsStoreController.durableSettings = ({id:widget.moduleName,showCount:false})
      widget.restoreFailedSettings()
      if (widget.settings.showCount !== false || widget.settingsSaveStatus !== "failed" || root.updates < 1)
        throw new Error("failed settings save did not restore widget and inline state")
      widget.settingsSaveStatus = "saving"
      widget.serviceCatalog = [{id:"syncthing",installedPackages:["syncthing"]}]
      var entry = {id:"syncthing",name:"Syncthing",active:false}
      widget.requestUninstall(entry)
      if (!widget.uninstallConfirmOpen || widget.uninstallTarget.id !== "syncthing") throw new Error("widget uninstall confirmation wiring failed")
      widget.cancelUninstall()
      widget.requestRestore(entry, "backup-1")
      if (!widget.restoreConfirmOpen || widget.restoreBackupName !== "backup-1") throw new Error("widget restore confirmation wiring failed")
      widget.cancelRestore()
      widget.adoptTransferredSettings({serviceGroupMode:"status",notifyUnhealthy:false,notifyUnexpectedStops:true,notificationCooldownSeconds:30,eventRefresh:false})
      widget.services = [{id:"running",name:"Running",active:true,hasError:false},{id:"stopped",name:"Stopped",active:false,hasError:false}]
      widget.collapsedServiceGroups = ({RUNNING:true})
      widget.selectedServiceId = "running"
      widget.activateServiceSelection()
      if (widget.selectedServiceId !== "stopped" || widget.expandedServiceId !== "stopped") throw new Error("collapsed service activation failed")
      widget.collapsedServiceGroups = ({RUNNING:true,STOPPED:true})
      widget.activateServiceSelection()
      if (widget.selectedServiceId !== "") throw new Error("all-collapsed service activation failed")
      widget.notificationLastAt = ({})
      widget.handleServiceTransitions([{id:"running",active:true,hasError:false}], [{id:"running",name:"Running",active:true,hasError:true}])
      if (Object.keys(widget.notificationLastAt).length !== 0) throw new Error("disabled notification consumed cooldown")
      widget.controlledUntil = ({running:Date.now() + 10000})
      widget.handleServiceTransitions([{id:"running",active:true,hasError:false}], [{id:"running",name:"Running",active:false,hasError:false}])
      if (Object.keys(widget.notificationLastAt).length !== 0) throw new Error("controlled stop consumed cooldown")
      if (!widget.transitionNotificationEligible({id:"running",kind:"stopped"}, {id:"running"}, Date.now() + 11000)) throw new Error("later unexpected stop was not eligible")
      if (widget.openSettings("invalid") !== "invalid page") throw new Error("settings IPC accepted an invalid page")
      if (widget.openSettings("performance") !== "ok" || !widget.opened || !widget.showingWidgetSettings || widget.settingsPage !== "performance") throw new Error("settings IPC navigation failed")
      if (!widget.settingsIndicatorVisible) throw new Error("settings loading presentation did not start")
      widget.adoptTransferredSettings({eventRefresh:false,showLoadingIndicators:false})
      if (widget.settingsIndicatorVisible) throw new Error("disabled loading preference did not release settings surface")
      widget.adoptTransferredSettings({eventRefresh:false,showLoadingIndicators:true})
      widget.showSettingsPage("general")
      root.settingsLoadDeadline = Date.now() + 2000
      root.stage = 1
      } else if (root.stage === 1) {
      if (!widget.settingsSurfaceLoaded) {
        if (Date.now() >= root.settingsLoadDeadline) throw new Error("lazy settings surface failed to load")
        return
      }
      if (widget.settingsIndicatorVisible) throw new Error("settings loading presentation did not settle")
      if (widget.settingsSaveStatus !== "saved") throw new Error("durable settings save status did not complete: " + widget.settingsSaveStatus)
      widget.helper = PathUtils.localFilePath(Qt.resolvedUrl("tests/fixtures/loading-helper"))
      widget.showSettingsPage("packages")
      root.stage = 2
      } else if (root.stage === 2) {
      if (!widget.catalogLoading) throw new Error("live catalog loading presentation was not retained")
      root.stage = 3
      } else if (root.stage === 3) {
      if (!widget.catalogLoading) throw new Error("long catalog loading presentation ended before request completion")
      widget.showSettingsPage("general")
      root.stage = 4
      } else if (root.stage === 4) {
      if (widget.catalogLoading) throw new Error("long catalog loading presentation did not settle")
      widget.settingsPage = "packages"
      widget.serviceCatalog = [{id:"preserved"}]
      widget.helper = "/usr/bin/false"
      widget.refresh(true, false, false)
      root.stage = 5
      } else if (root.stage === 5) {
      if (!widget.catalogLoading) throw new Error("fast catalog failure did not retain minimum loading presentation")
      root.stage = 6
      } else if (root.stage === 6) {
      if (widget.visibleErrorText !== "Service catalog refresh failed") throw new Error("catalog failure was not surfaced")
      if (widget.serviceCatalog.length !== 1 || widget.serviceCatalog[0].id !== "preserved") throw new Error("catalog failure replaced existing data")
      if (widget.catalogLoading) throw new Error("failed catalog loading presentation did not settle")
      widget.helper = root.fixtureHelper
      widget.refreshCatalog()
      root.stage = 7
      } else if (root.stage === 7) {
      if (!widget.catalogLoading) throw new Error("catalog recovery did not retain loading presentation")
      root.stage = 8
      } else if (root.stage === 8) {
      if (widget.catalogLoading || widget.catalogErrorText !== "" || widget.visibleErrorText === "Service catalog refresh failed") throw new Error("successful catalog retry did not clear its failure")
      console.log("P2P_QML_PLUGIN_SMOKE_OK")
      Qt.quit()
      }
    }
  }
}
