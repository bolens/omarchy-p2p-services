import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "packages"
    property bool availablePackagesExpanded: false
    property bool installedPackagesExpanded: false
    property bool runtimeActive: true
    property bool catalogLoading: true
    property var values: ({showLoadingIndicators:true})
    property string pendingService: ""
    property var events: []
    property var missingServices: [{id:"headscale"},{id:"a"},{id:"b"},{id:"c"},{id:"d"},{id:"e"}]
    property var visibleMissingServices: [{id:"headscale",name:"Headscale",icon:"H",packages:["headscale"]}]
    property var detectedServiceCatalog: [{id:"syncthing"},{id:"a"},{id:"b"},{id:"c"},{id:"d"},{id:"e"}]
    property var visibleDetectedServiceCatalog: [{id:"syncthing",name:"Syncthing",icon:"S",installedPackages:["syncthing"]}]
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function themeColor(_role, fallback) { return fallback }
    function service(id) { return {id:id,active:runtimeActive} }
    function installService(entry) { events = events.concat([{kind:"install",id:entry.id}]) }
    function act(entry, action) { events = events.concat([{kind:"action",id:entry.id,action:action}]) }
    function requestUninstall(entry) { events = events.concat([{kind:"uninstall",id:entry.id}]) }
  }

  P2PPackagesSettings { id: page; controller: mockController }

  function descendant(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    var children = item.children || []
    for (var index = 0; index < children.length; index++) {
      var match = descendant(children[index], name)
      if (match) return match
    }
    return null
  }

  Component.onCompleted: Qt.callLater(function() {
    var availableToggle = descendant(page, "availablePackagesToggle")
    var installedToggle = descendant(page, "installedPackagesToggle")
    var install = descendant(page, "installPackageButton-headscale")
    var stop = descendant(page, "stopPackageButton-syncthing")
    var uninstall = descendant(page, "uninstallPackageButton-syncthing")
    var loading = descendant(page, "catalogLoadingIndicator")
    var availableHeading = descendant(page, "availablePackagesHeading")
    var installedHeading = descendant(page, "installedPackagesHeading")
    var emptyCatalog = descendant(page, "emptyPackageCatalogText")
    if (!availableToggle || !installedToggle || !install || !stop || !uninstall || !loading || !availableHeading || !installedHeading || !emptyCatalog) throw new Error("package settings controls are not addressable")
    if (!availableHeading.visible || !installedHeading.visible || emptyCatalog.visible) throw new Error("populated package catalog presentation failed")
    if (!loading.visible || loading.label !== "QUERYING PACKAGE CATALOG") throw new Error("catalog loading state failed")
    mockController.values = ({showLoadingIndicators:false})
    if (loading.running) throw new Error("disabled loading preference did not hide active catalog indicator")
    mockController.values = ({showLoadingIndicators:true})
    if (!loading.running) throw new Error("re-enabled loading preference did not restore active catalog indicator")
    mockController.catalogLoading = false
    if (loading.visible) throw new Error("catalog loading indicator did not stop")
    availableToggle.clicked(); installedToggle.clicked(); install.clicked(); stop.clicked()
    if (!mockController.availablePackagesExpanded || !mockController.installedPackagesExpanded) throw new Error("package expansion actions failed")
    if (mockController.events.length !== 2 || mockController.events[0].kind !== "install" || mockController.events[0].id !== "headscale" || mockController.events[1].action !== "stop") throw new Error("package install/stop dispatch failed")
    if (!stop.visible || !stop.enabled || uninstall.enabled) throw new Error("running package action state failed")
    mockController.runtimeActive = false
    Qt.callLater(function() {
      if (stop.visible || !uninstall.enabled) throw new Error("stopped package action state failed")
      uninstall.clicked()
      if (mockController.events.length !== 3 || mockController.events[2].kind !== "uninstall" || mockController.events[2].id !== "syncthing") throw new Error("package uninstall dispatch failed")
      mockController.missingServices = []
      mockController.detectedServiceCatalog = []
      if (availableHeading.visible || installedHeading.visible || !emptyCatalog.visible) throw new Error("empty package catalog did not replace zero-count headings")
      mockController.catalogLoading = true
      mockController.settingsPage = "general"
      if (page.visible || !loading.running) throw new Error("catalog loading state was not preserved while navigating away")
      mockController.settingsPage = "packages"
      if (!loading.running) throw new Error("catalog loading state was lost after navigation back")
      console.log("P2P_QML_PACKAGES_SETTINGS_OK")
      Qt.quit()
    })
  })
}
