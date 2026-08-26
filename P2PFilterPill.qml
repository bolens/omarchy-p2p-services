import qs.Commons
import qs.Ui

Button {
  required property var controller
  required property string label
  required property string value
  readonly property real minimumPillWidth: label.length * Style.font.bodySmall * 0.62 + Style.spacing.controlPaddingX * 2
  text: label
  active: controller.serviceFilter === value
  selected: active
  bordered: true
  fontSize: Style.font.bodySmall
  horizontalPadding: Style.spacing.controlPaddingX
  verticalPadding: Style.spacing.controlPaddingY
  onClicked: controller.serviceFilter = value
}
