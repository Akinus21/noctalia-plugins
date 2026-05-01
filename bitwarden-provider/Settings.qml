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
    property string editPassword: cfg.password || ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.serverUrl = root.editServerUrl
        pluginApi.pluginSettings.email = root.editEmail
        pluginApi.pluginSettings.password = root.editPassword
        pluginApi.saveSettings()
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.serverUrl.label") ?? "Server URL"
        description: pluginApi?.tr("settings.serverUrl.desc") ?? "Your Bitwarden or Vaultwarden server URL (leave empty for default)"
        placeholderText: "https://vault.bitwarden.com"
        text: root.editServerUrl
        onTextChanged: root.editServerUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.email.label") ?? "Email"
        description: pluginApi?.tr("settings.email.desc") ?? "Saved for reference. bw serve reads from existing login session."
        placeholderText: "you@example.com"
        text: root.editEmail
        onTextChanged: root.editEmail = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NText {
            text: pluginApi?.tr("settings.password.label") ?? "Master Password"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        NText {
            text: pluginApi?.tr("settings.password.desc") ?? "Your master password for unlocking the vault"
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NBox {
                Layout.fillWidth: true
                implicitHeight: passwordField.implicitHeight + Style.marginM * 2
                radius: Style.radiusM

                TextInput {
                    id: passwordField
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Style.marginM
                    }
                    text: root.editPassword
                    echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                    color: Color.mOnSurface
                    font.pixelSize: 14
                    selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    onTextChanged: root.editPassword = text

                    Text {
                        anchors.fill: parent
                        text: "Your master password"
                        color: Color.mOnSurfaceVariant
                        font: passwordField.font
                        visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    }
                }
            }

            NButton {
                id: showPassword
                property bool checked: false
                text: checked ? "Hide" : "Show"
                outlined: true
                onClicked: checked = !checked
            }
        }
    }

    NText {
        text: pluginApi?.tr("settings.hint") ?? "Requires: brew install bitwarden-cli && bw serve --port 8087"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
    }
}
