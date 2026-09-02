pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

RowLayout {
  id: resetRow
  required property var controller
  Layout.fillWidth: true

  function reset() {
    var current = {}
    var keys = ["serviceLabels", "serviceIcons", "serviceShowStopped", "serviceConsoleUrls",
      "serviceNotificationPolicies", "favoriteServices", "serviceOrder"]
    for (var index = 0; index < keys.length; index++) current[keys[index]] = controller.setting(keys[index], Model.settingsDefaults()[keys[index]])
    controller.privacyFilterOverride = undefined
    controller.persistKeepingOpen(Model.globalSettingsResetPatch(current))
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 1
    Text { text: "RESTORE DEFAULTS"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 1.1 }
    Text { Layout.fillWidth: true; text: "Reset global widget options; per-service customizations are preserved."; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
  }
  Button { objectName: "settingsResetButton"; text: "Reset"; onClicked: resetRow.reset() }
}
