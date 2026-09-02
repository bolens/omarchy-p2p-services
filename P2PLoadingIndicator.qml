pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Commons
import "Model.js" as Model

Rectangle {
  id: indicator
  property bool running: false
  property string label: "Loading"
  property string style: "spinner"
  property string glyph: ">"
  property int speed: 140
  property bool compact: false
  property bool animationEnabled: true
  property color tone: Color.accent
  property int frameIndex: 0
  readonly property var frames: Model.loadingFrames(style, glyph)
  readonly property bool animationRunning: animationTimer.running
  readonly property int animationInterval: animationTimer.interval

  visible: running
  Layout.fillWidth: !compact
  implicitWidth: loadingRow.implicitWidth + (compact ? 0 : Style.spacing.md * 2)
  implicitHeight: loadingRow.implicitHeight + (compact ? 0 : Style.spacing.md * 2)
  radius: Style.cornerRadius
  color: compact ? "transparent" : Util.alpha(tone, 0.055)
  border.width: compact ? 0 : 1
  border.color: Util.alpha(tone, 0.16)

  RowLayout {
    id: loadingRow
    anchors.fill: parent
    anchors.margins: indicator.compact ? 0 : Style.spacing.md
    spacing: Style.spacing.sm
    Text {
      objectName: "loadingFrame"
      text: indicator.frames[indicator.frameIndex % indicator.frames.length]
      textFormat: Text.PlainText
      color: indicator.tone
      font.family: Style.font.mono || Style.font.family
      font.pixelSize: Style.font.body
      font.weight: Font.DemiBold
    }
    Text {
      objectName: "loadingLabel"
      Layout.fillWidth: true
      text: indicator.label
      textFormat: Text.PlainText
      color: Color.muted
      font.family: Style.font.mono || Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.7
    }
  }

  Timer {
    id: animationTimer
    objectName: "loadingAnimationTimer"
    interval: Math.max(60, indicator.speed)
    running: indicator.running && indicator.animationEnabled && indicator.frames.length > 1
    repeat: true
    onTriggered: indicator.frameIndex = (indicator.frameIndex + 1) % indicator.frames.length
  }
  onRunningChanged: if (running) frameIndex = 0
}
