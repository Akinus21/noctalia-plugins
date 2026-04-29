import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editVaultUrl: cfg.vaultUrl ?? defaults.vaultUrl ?? ""
    property string editSessionToken: cfg.sessionToken ?? defaults.sessionToken ?? ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.vaultUrl = root.editVaultUrl
        pluginApi.pluginSettings.sessionToken = root.editSessionToken
        pluginApi.saveSettings()
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Vault URL"
        description: "Your Bitwarden/vaultwarden server URL"
        placeholderText: "https://bitwarden.example.com"
        text: root.editVaultUrl
        onTextChanged: root.editVaultUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Session Token"
        description: "Output of 'bw unlock' to persist login"
        placeholderText: "Run 'bw unlock' then copy the token"
        text: root.editSessionToken
        onTextChanged: root.editSessionToken = text
    }

    NText {
        text: "Make sure bw CLI is installed and your vault is unlocked."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    NButton {
        text: "Open Bitwarden Download Page"
        outlined: true
        Layout.fillWidth: true
        onClicked: Quickshell.execDetached(["xdg-open", "https://bitwarden.com/download"])
    }
}
