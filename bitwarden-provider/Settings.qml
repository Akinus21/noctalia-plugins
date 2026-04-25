import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string vaultUrl: cfg.vaultUrl ?? defaults.vaultUrl ?? ""
    property string sessionToken: cfg.sessionToken ?? defaults.sessionToken ?? ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.vaultUrl = root.vaultUrl
        pluginApi.pluginSettings.sessionToken = root.sessionToken
        pluginApi.saveSettings()
        if (pluginApi.mainInstance) {
            pluginApi.mainInstance.checkUnlockStatus()
        }
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Vault URL (optional)"
        description: "Your Bitwarden/vaultwarden server URL"
        placeholderText: "https://bitwarden.example.com"
        text: root.vaultUrl
        onTextChanged: root.vaultUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Session Token (optional)"
        description: "Paste output of 'bw unlock' — avoids re-authentication"
        placeholderText: "Run 'bw unlock' in terminal, then 'echo $BW_SESSION'"
        text: root.sessionToken
        onTextChanged: root.sessionToken = text
    }

    NLabel {
        text: "Make sure <b>bw CLI</b> is installed and your vault is unlocked."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        color: Color.mOnSurfaceVariant
    }

    NButton {
        text: "Open Bitwarden Download Page"
        outlined: true
        Layout.fillWidth: true
        onClicked: Quickshell.execDetached(["xdg-open", "https://bitwarden.com/download"])
    }
}