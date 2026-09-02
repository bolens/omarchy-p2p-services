pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

        ColumnLayout {
          id: editor
  required property var controller
          visible: editor.controller.editingServiceId !== ""
          Layout.fillWidth: true
          spacing: Style.spacing.md
          readonly property var current: editor.controller.service(editor.controller.editingServiceId)

          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "serviceEditorBackButton"; iconText: "󰁍"; tooltipText: "Back to services"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.editingServiceId = "" }
            Text {
              objectName: "serviceEditorTitle"
              Layout.fillWidth: true
              text: editor.current ? editor.controller.labelFor(editor.current) + " settings" : "Service settings"
              textFormat: Text.PlainText
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.weight: Font.DemiBold
            }
            Button {
              objectName: "serviceEditorPreviousButton"
              iconText: "󰅁"
              tooltipText: "Previous visible service"
              enabled: editor.controller.canMoveServiceEditor(editor.controller.editingServiceId, -1)
              horizontalPadding: Style.spacing.controlGap
              onClicked: editor.controller.moveServiceEditor(-1)
            }
            Button {
              objectName: "serviceEditorNextButton"
              iconText: "󰅂"
              tooltipText: "Next visible service"
              enabled: editor.controller.canMoveServiceEditor(editor.controller.editingServiceId, 1)
              horizontalPadding: Style.spacing.controlGap
              onClicked: editor.controller.moveServiceEditor(1)
            }
          }

          P2PSectionHeading { title: "Identity"; description: "Customize how this service appears in the list." }
          Toggle {
            Layout.fillWidth: true
            label: "Favorite service"
            description: "Keep this service above non-favorites in every sorting mode."
            checked: editor.controller.isFavorite(editor.controller.editingServiceId)
            foreground: Color.popups.text
            accent: Color.bar.active
            fontFamily: Style.font.family
            onClicked: editor.controller.toggleFavorite(editor.controller.editingServiceId)
          }
          RowLayout {
            Layout.fillWidth: true
            TextField {
              id: serviceLabelEditor
              objectName: "serviceLabelEditor"
              Layout.fillWidth: true
              placeholderText: "Display label"
              text: editor.current ? editor.controller.labelFor(editor.current) : ""
              foreground: Color.popups.text
              accent: Color.bar.active
              font.family: Style.font.family
              onAccepted: editor.controller.persistServiceMap("serviceLabels", editor.controller.editingServiceId, text, true)
            }
            Button { objectName: "serviceLabelSaveButton"; iconText: "󰆓"; tooltipText: "Save service label"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.persistServiceMap("serviceLabels", editor.controller.editingServiceId, serviceLabelEditor.text, true) }
          }
          RowLayout {
            Layout.fillWidth: true
            TextField {
              id: serviceIconEditor
              objectName: "serviceIconEditor"
              Layout.fillWidth: true
              placeholderText: "Icon"
              text: editor.current ? String(editor.controller.iconFor(editor.current) || "") : ""
              foreground: Color.popups.text
              accent: Color.bar.active
              font.family: Style.font.family
              onAccepted: editor.controller.persistServiceMap("serviceIcons", editor.controller.editingServiceId, text, true)
            }
            Button { objectName: "serviceIconSaveButton"; iconText: "󰆓"; tooltipText: "Save service icon"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.persistServiceMap("serviceIcons", editor.controller.editingServiceId, serviceIconEditor.text, true) }
          }

          P2PSectionHeading { title: "Console and visibility"; description: "Choose when the service appears and where its web console opens." }
          Toggle {
            Layout.fillWidth: true
            label: "Show while stopped"
            description: "Keep this service visible when it is installed but not running."
            checked: editor.controller.serviceShowsStopped(editor.controller.editingServiceId)
            foreground: Color.popups.text
            accent: Color.bar.active
            fontFamily: Style.font.family
            onClicked: editor.controller.persistServiceMap("serviceShowStopped", editor.controller.editingServiceId, !checked, false)
          }
          Dropdown {
            objectName: "serviceNotificationPolicyDropdown"
            Layout.fillWidth: true
            label: "Action notifications"
            value: editor.controller.serviceNotificationPolicy(editor.controller.editingServiceId)
            options: [{value:"inherit",label:"Use global setting"},{value:"always",label:"Always"},{value:"failures",label:"Failures only"},{value:"silent",label:"Silent"}]
            foreground: Color.popups.text
            accent: Color.bar.active
            onChanged: function(next) { editor.controller.persistServiceMap("serviceNotificationPolicies", editor.controller.editingServiceId, next, next === "inherit") }
          }

          TextField {
            id: serviceConsoleEditor
            objectName: "serviceConsoleEditor"
            Layout.fillWidth: true
            placeholderText: "Console URL (http:// or https://)"
            text: editor.current ? editor.controller.consoleUrl(editor.current) : ""
            foreground: Color.popups.text
            accent: Color.bar.active
            font.family: Style.font.family
            onAccepted: editor.controller.saveConsoleUrl(editor.controller.editingServiceId, text)
          }
          P2PSectionHeading { title: "Ordering and backend"; description: "Reorder this card or inspect the detected control source." }
          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "serviceConsoleSaveButton"; iconText: "󰆓"; tooltipText: "Save console URL"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.saveConsoleUrl(editor.controller.editingServiceId, serviceConsoleEditor.text) }
            Button { text: "Open configured console"; enabled: editor.controller.hasConsole(editor.current); onClicked: editor.controller.openConsole(editor.current) }
            Item { Layout.fillWidth: true }
          }

          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "serviceMoveUpButton"; iconText: "󰁝"; tooltipText: "Move service up"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.moveService(editor.controller.editingServiceId, -1) }
            Button { objectName: "serviceMoveDownButton"; iconText: "󰁅"; tooltipText: "Move service down"; horizontalPadding: Style.spacing.controlGap; onClicked: editor.controller.moveService(editor.controller.editingServiceId, 1) }
            Button { objectName: "serviceConfigButton"; iconText: "󰒓"; tooltipText: "Open service configuration"; horizontalPadding: Style.spacing.controlGap; visible: !!editor.current && editor.current.configExists === true && editor.current.controllable !== false; onClicked: editor.controller.act(editor.current, "config") }
            Item { Layout.fillWidth: true }
          }

          Text {
            Layout.fillWidth: true
            text: editor.current ? ("Backend: " + editor.current.id + "\nControl: " + (editor.current.unit || "exact process name") + "\n" + Model.summary(editor.current, editor.controller.privacyFilter)) : ""
            textFormat: Text.PlainText
            color: Color.muted
            wrapMode: Text.WordWrap
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            Layout.fillWidth: true
            readonly property var catalog: editor.controller.catalogEntry(editor.controller.editingServiceId)
            text: catalog && catalog.backups && catalog.backups.length ? (catalog.backups.length + " configuration backup" + (catalog.backups.length === 1 ? "" : "s") + " · latest " + catalog.backups[0].timestamp) : "No configuration backups"
            textFormat: Text.PlainText
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          ColumnLayout {
            Layout.fillWidth: true
            visible: {
              var item = editor.controller.catalogEntry(editor.controller.editingServiceId)
              return !!editor.current && editor.current.controllable !== false && !!item && item.backups && item.backups.length > 0
            }
            spacing: Style.spacing.xs
            Repeater {
              model: {
                var item = editor.controller.catalogEntry(editor.controller.editingServiceId)
                return item && item.backups ? item.backups : []
              }
              delegate: RowLayout {
                id: backupRow
                required property var modelData
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: backupRow.modelData.timestamp; textFormat: Text.PlainText; color: Color.muted; elide: Text.ElideRight; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                Button { objectName: "serviceRestoreButton"; text: "Restore"; enabled: !!editor.current && !editor.current.active; tooltipText: enabled ? "Restore this configuration backup" : "Stop the service before restoring configuration"; onClicked: if (enabled) editor.controller.requestRestore(editor.current, backupRow.modelData.name) }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            Button { objectName: "serviceResetButton"; text: "Reset service settings"; onClicked: editor.controller.resetService(editor.controller.editingServiceId) }
            Item { Layout.fillWidth: true }
            Button {
              objectName: "serviceUninstallButton"
              text: "Uninstall"
              visible: editor.controller.canUninstall(editor.current)
              enabled: editor.current && !editor.current.active
              tooltipText: enabled ? "Uninstall packages and preserve a private config backup" : "Stop the service before uninstalling"
              onClicked: editor.controller.requestUninstall(editor.current)
            }
          }
        }
