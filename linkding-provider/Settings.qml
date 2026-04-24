import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    Component.onCompleted: {
        Logger.i("LinkdingSettings", "Settings loaded, pluginApi:", pluginApi)
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("LinkdingSettings", "Cannot save: pluginApi is null")
            return
        }
        pluginApi.saveSettings()
        Logger.i("LinkdingSettings", "Settings saved")
    }

    NLabel {
        label: "Linkding Settings"
        description: "Configure your Linkding bookmark provider"
    }

    NTextInput {
        id: urlInput
        Layout.fillWidth: true
        label: "Linkding URL"
        placeholderText: "https://links.yourdomain.com"
        text: pluginApi?.pluginSettings?.linkdingUrl ?? ""
    }

    NTextInput {
        id: tokenInput
        Layout.fillWidth: true
        label: "API Token"
        placeholderText: "your-api-token-here"
        text: pluginApi?.pluginSettings?.apiToken ?? ""
    }
}