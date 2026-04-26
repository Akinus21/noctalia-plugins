import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string linkdingUrl: cfg.linkdingUrl || defaults.linkdingUrl || ""
    property string apiToken: cfg.apiToken || defaults.apiToken || ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.vaultUrl = root.linkdingUrl
        pluginApi.pluginSettings.sessionToken = root.apiToken
        pluginApi.saveSettings()
    }
}