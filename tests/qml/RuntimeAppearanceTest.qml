import Quickshell
import QtQuick

ShellRoot {
  id: root

  QtObject {
    id: mockController
    property string settingsPage: "appearance"
    property var values: ({barPresentation:"active",categoryIcons:{}})
    property var events: []
    function setting(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function persistKeepingOpen(patch) { events = events.concat([patch]); values = Object.assign({}, values, patch) }
    function categorySummaries() { return [{category:"File sync",icon:"S",active:1,total:1,text:"S 1"}] }
    function saveCategoryIcon(category, icon) { events = events.concat([{category:category,icon:icon}]) }
  }

  P2PAppearanceSettings { id: appearance; width: 620; controller: mockController }

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
    var presentation = descendant(appearance, "barPresentationDropdown")
    var widgetIcon = descendant(appearance, "widgetIconEditor")
    var widgetIconSave = descendant(appearance, "widgetIconSaveButton")
    var rotation = descendant(appearance, "barTextRotationDropdown")
    var layout = descendant(appearance, "serviceLayoutDropdown")
    var density = descendant(appearance, "cardDensityDropdown")
    var groupStyle = descendant(appearance, "groupHeaderStyleDropdown")
    var runningRole = descendant(appearance, "themeRole-runningColorRole")
    var loadingStyle = descendant(appearance, "loadingIndicatorStyleDropdown")
    var barBehaviorGrid = descendant(appearance, "barBehaviorGrid")
    var barStyleGrid = descendant(appearance, "barStyleGrid")
    var loadingGrid = descendant(appearance, "loadingIndicatorGrid")
    var themeGrid = descendant(appearance, "themeRoleGrid")
    if (!presentation || !widgetIcon || !widgetIconSave || !rotation || !layout || !density || !groupStyle || !runningRole || !loadingStyle || !barBehaviorGrid || !barStyleGrid || !loadingGrid || !themeGrid) throw new Error("appearance controls missing")
    if (widgetIconSave.text !== "" || widgetIconSave.iconText !== "󰆓" || widgetIconSave.tooltipText !== "Save bar icon") throw new Error("bar icon save action is not a descriptive icon control")
    for (var wideGrid of [barBehaviorGrid, barStyleGrid, loadingGrid, themeGrid])
      if (!wideGrid.twoColumns || wideGrid.columns !== 2) throw new Error("wide appearance settings did not use two columns")
    if (runningRole.label !== "Running color") throw new Error("theme role label was not retained")
    layout.changed("grid")
    presentation.changed("category-active-total")
    Qt.callLater(function() {
      var editor = descendant(appearance, "categoryIconEditor")
      if (!editor) throw new Error("category icon editor missing")
      editor.text = "M"
      editor.accepted()
      editor.text = ""
      editor.accepted()
      widgetIcon.text = "  "; widgetIcon.accepted()
      rotation.changed("clockwise")
      density.changed("minimal")
      groupStyle.changed("dense")
      runningRole.changed("urgent")
      loadingStyle.changed("glyph")
      Qt.callLater(function() {
      var loadingGlyph = descendant(appearance, "loadingIndicatorGlyphEditor")
      if (!loadingGlyph || !loadingGlyph.visible) throw new Error("custom loading glyph control failed")
      loadingGlyph.text = "#"; loadingGlyph.accepted()
      if (mockController.events.length !== 11) throw new Error("appearance event count mismatch")
      if (mockController.events[0].serviceLayout !== "grid") throw new Error("service layout event failed")
      if (mockController.events[1].barPresentation !== "category-active-total") throw new Error("category presentation event failed")
      if (mockController.events[2].category !== "File sync" || mockController.events[2].icon !== "M") throw new Error("category icon save failed")
      if (mockController.events[3].icon !== "") throw new Error("category icon clear failed")
      if (mockController.events[4].widgetIcon !== "󰒍") throw new Error("blank widget icon fallback failed")
      if (mockController.events[5].barTextRotation !== "clockwise") throw new Error("bar rotation event failed")
      if (mockController.events[6].cardDensity !== "minimal") throw new Error("card density event failed")
      if (mockController.events[7].groupHeaderStyle !== "dense") throw new Error("group style event failed")
      if (mockController.events[8].runningColorRole !== "urgent") throw new Error("theme role event failed")
      if (mockController.events[9].loadingIndicatorStyle !== "glyph" || mockController.events[10].loadingIndicatorGlyph !== "#") throw new Error("loading appearance events failed")
      loadingStyle.changed("spinner")
      presentation.changed("active")
      mockController.values = Object.assign({}, mockController.values, {runningColorRole:"muted"})
      Qt.callLater(function() {
        if (loadingGlyph.visible) throw new Error("custom glyph editor remained visible outside glyph mode")
        if (descendant(appearance, "categoryIconEditor")) throw new Error("category icon editors remained after category presentation was disabled")
        if (runningRole.value !== "muted") throw new Error("theme role control ignored externally reloaded settings")
        console.log("P2P_QML_APPEARANCE_OK")
        Qt.quit()
      })
      })
    })
  })
}
