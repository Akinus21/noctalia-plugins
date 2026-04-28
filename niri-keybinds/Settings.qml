import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editConfigPath: cfg.configPath ?? defaults.configPath ?? ""

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.configPath = root.editConfigPath
        pluginApi.saveSettings()
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Config Path"
        description: "Path to niri config file"
        placeholderText: "~/.config/niri/config.kdl"
        text: root.editConfigPath
        onTextChanged: root.editConfigPath = text
    }

    NLabel {
        text: "Changes require a panel reload to take effect."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        color: Color.mOnSurfaceVariant
    }
}