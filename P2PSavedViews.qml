pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: views
  required property var controller
  Layout.fillWidth: true
  implicitHeight: viewRow.implicitHeight + Style.spacing.md * 2
  radius: Style.cornerRadius
  color: Util.alpha(Color.accent, 0.035)
  border.width: 1
  border.color: Util.alpha(Color.accent, 0.12)

  function activate(index) {
    var saved = controller.setting("savedViews", []) || []
    if (index >= 0 && index < saved.length) controller.applyView(saved[index])
  }

  RowLayout {
    id: viewRow
    anchors.fill: parent
    anchors.margins: Style.spacing.md
    spacing: Style.spacing.xs
    Text { text: "VIEWS"; textFormat: Text.PlainText; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.Bold; font.letterSpacing: 1.0 }
    Repeater {
      model: (views.controller.setting("savedViews", []) || []).slice(0, 3)
      delegate: Button { required property var modelData; required property int index; objectName: "savedViewButton-" + index; text: String(modelData.name).slice(0, 16); tooltipText: modelData.name; onClicked: views.activate(index) }
    }
    Item { Layout.fillWidth: true }
  }
}
