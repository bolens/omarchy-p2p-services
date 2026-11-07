pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// ONE instance owned by the already shared keepLoaded P2P Service.
QtObject {
    id: hub
    required property QtObject serviceIdentity
    readonly property string targetName: "io.github.bolens.p2p-services"
    property var entries: []
    property int nextLease: 0
    readonly property int widgetCount: entries.length
    property string routingError: ""

    function registerWidget(widget, moduleName, service) {
        if (!widget || moduleName !== hub.targetName || widget.moduleName !== hub.targetName
                || service !== hub.serviceIdentity || widget.p2pService !== hub.serviceIdentity) return 0
        const existing = hub.entries.find(function(row) { return row.widget === widget })
        if (existing) return existing.lease
        if (hub.nextLease >= 2147483647) return 0
        hub.nextLease += 1
        const lease = hub.nextLease
        hub.entries = hub.entries.concat([{widget:widget, lease:lease}])
        return lease
    }
    function unregisterWidget(widget, lease) {
        const before = hub.entries.length
        hub.entries = hub.entries.filter(function(row) { return row.widget !== widget || row.lease !== lease })
        return hub.entries.length !== before
    }
    function focusedWidget() {
        hub.routingError = ""
        const rows = hub.entries.filter(function(row) {
            return row.widget && row.widget.moduleName === hub.targetName && row.widget.p2pService === hub.serviceIdentity
        })
        let selected = null
        for (const row of rows) {
            const candidate = typeof row.widget.ipcFocusedPanel === "function" ? row.widget.ipcFocusedPanel() : null
            if (!candidate) continue
            if (!rows.some(function(member) { return member.widget === candidate })) {
                hub.routingError = "foreign focus result"
                return null
            }
            if (selected && selected !== candidate) {
                hub.routingError = "conflicting focus results"
                return null
            }
            selected = candidate
        }
        if (selected) return selected
        // Without a valid focus capability, only one member is unambiguous.
        if (rows.length === 1) return rows[0].widget
        hub.routingError = "focus resolver unavailable"
        return null
    }

    function dispatch(method, args) {
        if (method === "captureContract") return "2"
        const widget = hub.focusedWidget()
        if (!widget) {
            if (["mainReady","detailsReady","editorReady","filtersReady","panelClosed","settingsReady","privacyEnabled"].indexOf(method) >= 0) return "false"
            if (method === "settingsSnapshot") return "{}"
            return "unavailable"
        }
        switch (method) {
        case "captureContract": return widget.captureContractVersion()
        case "open": return widget.openMainView()
        case "close": return widget.closeFocused()
        case "mainReady": return widget.focusedMainReady(args[0],args[1]) ? "true" : "false"
        case "openDetails": return widget.openServiceDetails(args[0])
        case "detailsReady": return widget.focusedDetailsReady(args[0]) ? "true" : "false"
        case "openEditor": return widget.openServiceEditor(args[0])
        case "editorReady": return widget.focusedEditorReady(args[0]) ? "true" : "false"
        case "showFilters": return widget.setFiltersExpanded(true)
        case "filtersReady": return widget.focusedFiltersExpanded() ? "true" : "false"
        case "panelClosed": return widget.focusedPanelClosed() ? "true" : "false"
        case "openSettings": return widget.openSettings(args[0])
        case "scrollSettings": return widget.setSettingsScroll(args[0])
        case "settingsReady": return widget.focusedSettingsReady(args[0]) ? "true" : "false"
        case "reloadSettings": return widget.reloadSettingsAcrossInstances()
        case "settingsSnapshot": return widget.focusedSettingsSnapshot()
        case "privacyEnabled": return widget.privacyFilter ? "true" : "false"
        default: return "unavailable"
        }
    }
    readonly property IpcHandler handler: IpcHandler {
        target: hub.targetName
        enabled: hub.widgetCount > 0
        function captureContract(): string { return hub.dispatch("captureContract",[]) }
        function open(): string { return hub.dispatch("open",[]) }
        function close(): string { return hub.dispatch("close",[]) }
        function mainReady(layout: string, density: string): string { return hub.dispatch("mainReady",[layout,density]) }
        function openDetails(serviceId: string): string { return hub.dispatch("openDetails",[serviceId]) }
        function detailsReady(serviceId: string): string { return hub.dispatch("detailsReady",[serviceId]) }
        function openEditor(serviceId: string): string { return hub.dispatch("openEditor",[serviceId]) }
        function editorReady(serviceId: string): string { return hub.dispatch("editorReady",[serviceId]) }
        function showFilters(): string { return hub.dispatch("showFilters",[]) }
        function filtersReady(): string { return hub.dispatch("filtersReady",[]) }
        function panelClosed(): string { return hub.dispatch("panelClosed",[]) }
        function openSettings(page: string): string { return hub.dispatch("openSettings",[page]) }
        function scrollSettings(position: string): string { return hub.dispatch("scrollSettings",[position]) }
        function settingsReady(page: string): string { return hub.dispatch("settingsReady",[page]) }
        function reloadSettings(): string { return hub.dispatch("reloadSettings",[]) }
        function settingsSnapshot(): string { return hub.dispatch("settingsSnapshot",[]) }
        function privacyEnabled(): string { return hub.dispatch("privacyEnabled",[]) }
    }
}
