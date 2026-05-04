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

    function ensureUnlocked(callback) {
        if (provider) {
            provider.ensureUnlocked(callback)
        } else {
            Logger.w("BitwardenMain", "ensureUnlocked: no provider")
            if (callback) callback()
        }
    }

    function autoType(username, password) {
        if (provider) {
            provider.autoType(username, password)
        } else {
            Logger.w("BitwardenMain", "autoType: no provider")
        }
    }

    function refreshItems() {
        if (provider) {
            provider.loaded = false
            provider.fetchItems()
        }
    }
}
