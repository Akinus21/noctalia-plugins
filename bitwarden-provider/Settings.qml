import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

    Component.onCompleted: {
        editPassword = cfg.password || ""
    }

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
        label: pluginApi?.tr("settings.serverUrl.label")
        description: pluginApi?.tr("settings.serverUrl.desc")
        placeholderText: "https://vault.bitwarden.com"
        text: root.editServerUrl
        onTextChanged: root.editServerUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.email.label")
        description: pluginApi?.tr("settings.email.desc")
        placeholderText: "you@example.com"
        text: root.editEmail
        onTextChanged: root.editEmail = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.password.label")
        description: pluginApi?.tr("settings.password.desc")
        placeholderText: "Your master password"
        echoMode: TextInput.Password
        text: root.editPassword
        onTextChanged: root.editPassword = text
    }

    NLabel {
        text: pluginApi?.tr("settings.hint")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        color: Color.mOnSurfaceVariant
    }
}