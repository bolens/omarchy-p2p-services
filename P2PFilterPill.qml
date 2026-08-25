import qs.Commons
import qs.Ui

Button {
  required property var controller
  required property string label
  required property string value
  text: label
  active: controller.serviceFilter === value
  selected: active
  bordered: true
  fontSize: Style.font.bodySmall
  horizontalPadding: Style.spacing.controlPaddingX
  verticalPadding: Style.spacing.controlPaddingY
  onClicked: controller.serviceFilter = value
}
