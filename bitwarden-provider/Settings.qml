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

    NTextInput {
        Layout.fillWidth: true
        label: "Server URL"
        description: "Your Bitwarden or Vaultwarden server URL"
        placeholderText: "https://vault.bitwarden.com"
        text: root.editServerUrl
        onTextChanged: root.editServerUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Email"
        description: "Your Bitwarden account email"
        placeholderText: "you@example.com"
        text: root.editEmail
        onTextChanged: root.editEmail = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Master Password"
        description: "Your Bitwarden master password (stored locally)"
        placeholderText: "Your master password"
        echoMode: TextInput.Password
        text: root.editPassword
        onTextChanged: root.editPassword = text
    }

    NLabel {
        text: "Uses the Bitwarden Flatpak (com.bitwarden.desktop). Configure your server URL and login credentials above."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        color: Color.mOnSurfaceVariant
    }
}