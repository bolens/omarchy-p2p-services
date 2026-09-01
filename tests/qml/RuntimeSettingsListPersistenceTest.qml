import "Model.js" as Model
import QtQuick
import Quickshell

ShellRoot {
    id: root

    property var loadedServices: ({
        "0": "syncthing",
        "1": "i2pd",
        "length": 2
    })

    Component.onCompleted: {
        if (Model.enabled(root.loadedServices, []).join("|") !== "syncthing|i2pd")
            throw new Error("loaded service selection reset");

        if (!store.save({
            "enabledServices": root.loadedServices
        }, null))
            throw new Error("service list save did not start");

    }

    P2PSettingsStore {
        id: store

        helper: "/usr/bin/true"
        moduleName: "io.github.bolens.p2p-services"
        onSaved: {
            var reloaded = JSON.parse(JSON.stringify(store.durableSettings));
            if (Model.enabled(reloaded.enabledServices, []).join("|") !== "syncthing|i2pd")
                throw new Error("enabled service selection reset after save and reload");

            console.log("P2P_QML_SETTINGS_LIST_PERSISTENCE_OK");
            Qt.quit();
        }
    }

}
