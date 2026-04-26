import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string bitwardenUrl: cfg.bitwardenUrl ?? defaults.bitwardenUrl ?? ""
    property string apiToken: cfg.apiToken ?? defaults.apiToken ?? ""
    property int cacheMaxAgeHours: cfg.cacheMaxAgeHours ?? defaults.cacheMaxAgeHours ?? 1
    property int cacheMaxAgeMinutes: cfg.cacheMaxAgeMinutes ?? defaults.cacheMaxAgeMinutes ?? 0
    property int cacheMaxAgeSeconds: cfg.cacheMaxAgeSeconds ?? defaults.cacheMaxAgeSeconds ?? 0

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) {
            return
        }
        pluginApi.pluginSettings.bitwardenUrl = root.bitwardenUrl
        pluginApi.pluginSettings.apiToken = root.apiToken
        pluginApi.pluginSettings.cacheMaxAgeHours = root.cacheMaxAgeHours
        pluginApi.pluginSettings.cacheMaxAgeMinutes = root.cacheMaxAgeMinutes
        pluginApi.pluginSettings.cacheMaxAgeSeconds = root.cacheMaxAgeSeconds
        pluginApi.saveSettings()
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Bitwarden URL"
        placeholderText: "https://links.yourdomain.com"
        text: root.bitwardenUrl
        onTextChanged: root.bitwardenUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "API Token"
        placeholderText: "your-api-token-here"
        text: root.apiToken
        onTextChanged: root.apiToken = text
    }
}