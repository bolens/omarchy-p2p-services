import qs.Commons
import qs.Ui

Button {
  required property var controller
  required property string label
  required property string value
  property string icon: ""
  property string count: ""
  readonly property real minimumPillWidth: Math.max(implicitHeight, count.length * Style.font.bodySmall * 0.62 + Style.spacing.controlPaddingX * 2 + (icon ? Style.font.bodySmall : 0))
  text: count
  iconText: icon
  tooltipText: label + (count ? " (" + count + ")" : "")
  active: controller.serviceFilter === value
  selected: active
  bordered: true
  fontSize: Style.font.bodySmall
  horizontalPadding: Style.spacing.controlPaddingX
  verticalPadding: Style.spacing.controlPaddingY
  onClicked: controller.serviceFilter = value
}
