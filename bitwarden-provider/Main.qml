import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root
    property var pluginApi: null

    // Shared state bridge — the LauncherProvider registers itself here
    property var provider: null

    function createItem(itemData, callback) {
        if (provider) {
            provider.createItem(itemData, callback)
        } else {
            Logger.w("BitwardenMain", "No provider registered")
            if (callback) callback(false, "Provider not ready")
        }
    }

    function refreshItems() {
        if (provider) {
            provider.loaded = false
            provider.fetchItems()
        }
    }
}
