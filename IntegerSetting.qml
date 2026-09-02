import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: field
  required property var controller
  required property string settingKey
  required property string label
  required property int minimum
  required property int maximum
  required property int fallback
  property string description: ""

  Layout.fillWidth: true
  spacing: Style.spacing.xs

  Text { text: field.label + " (" + field.minimum + "–" + field.maximum + ")"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
  Text { visible: field.description !== ""; Layout.fillWidth: true; text: field.description; textFormat: Text.PlainText; color: Color.muted; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
  RowLayout {
    Layout.fillWidth: true
    TextField {
      id: editor
      objectName: "integerSettingEditor"
      Layout.fillWidth: true
      text: String(field.controller.setting(field.settingKey, field.fallback))
      inputMethodHints: Qt.ImhDigitsOnly
      foreground: Color.popups.text
      accent: Color.bar.active
      font.family: Style.font.family
      validator: IntValidator { bottom: field.minimum; top: field.maximum }
      onAccepted: field.save()
    }
    Button { objectName: "integerSettingSaveButton"; iconText: "󰆓"; tooltipText: "Save " + field.label.toLowerCase(); horizontalPadding: Style.spacing.controlGap; enabled: editor.acceptableInput; onClicked: field.save() }
  }

  function save() {
    var raw = String(editor.text).trim()
    var parsed = Number(raw)
    if (raw === "" || !isFinite(parsed)) parsed = fallback
    var value = Math.max(minimum, Math.min(maximum, Math.round(parsed)))
    var update = {}
    update[settingKey] = value
    controller.persistKeepingOpen(update)
    editor.text = Qt.binding(function() { return String(field.controller.setting(field.settingKey, field.fallback)) })
  }
}
