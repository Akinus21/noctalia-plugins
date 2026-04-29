import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editServerUrl: cfg.serverUrl ?? defaults.serverUrl ?? ""
    property string editEmail: cfg.email ?? defaults.email ?? ""
    property string editPassword: ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.serverUrl = root.editServerUrl
        pluginApi.pluginSettings.email = root.editEmail
        if (root.editPassword) {
            pluginApi.pluginSettings.password = root.editPassword
        }
        pluginApi.saveSettings()
    }

    RowLayout {
        Layout.fillWidth: true
        NLabel { text: "Server:" }
        NTextInput {
            Layout.fillWidth: true
            placeholderText: "https://vault.bitwarden.com"
            text: root.editServerUrl
            onTextChanged: root.editServerUrl = text
        }
    }

    RowLayout {
        Layout.fillWidth: true
        NLabel { text: "Email:" }
        NTextInput {
            Layout.fillWidth: true
            placeholderText: "you@example.com"
            text: root.editEmail
            onTextChanged: root.editEmail = text
        }
    }

    RowLayout {
        Layout.fillWidth: true
        NLabel { text: "Password:" }
        NTextInput {
            Layout.fillWidth: true
            placeholderText: "Master password"
            text: root.editPassword
            onTextChanged: root.editPassword = text
        }
    }

    NLabel {
        text: "Hint: Use Bitwarden flatpak CLI"
        Layout.fillWidth: true
    }
}