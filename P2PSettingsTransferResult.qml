import QtQuick
import "Model.js" as Model

QtObject {
  required property var controller
  required property string moduleName

  signal errorRequested(string message)

  function apply(mode, payload) {
    if (mode === "export") {
      controller.notify("P2P settings", "Exported settings-export.json to the P2P Services user data directory")
      return true
    }
    if (mode !== "import" && mode !== "undo") return false
    var result = Model.parseTransferredSettings(payload, moduleName, mode)
    if (!result.valid) { errorRequested("Imported settings are invalid"); return false }
    if (mode === "import") controller.persistKeepingOpen(result.settings)
    else controller.adoptTransferredSettings(result.settings)
    controller.notify("P2P settings", mode === "import" ? "Imported settings successfully" : "Restored previous settings")
    return true
  }
}
