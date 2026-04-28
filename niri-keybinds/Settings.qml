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
    property bool editShowDesktop: cfg.showDesktopBindings ?? defaults.showDesktopBindings ?? true
    property bool editShowWindow: cfg.showWindowBindings ?? defaults.showWindowBindings ?? true
    property bool editShowLauncher: cfg.showLauncherBindings ?? defaults.showLauncherBindings ?? true

    spacing: Style.marginL

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.configPath = root.editConfigPath
        pluginApi.pluginSettings.showDesktopBindings = root.editShowDesktop
        pluginApi.pluginSettings.showWindowBindings = root.editShowWindow
        pluginApi.pluginSettings.showLauncherBindings = root.editShowLauncher
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

    NSwitch {
        Layout.fillWidth: true
        label: "Show Desktop Bindings"
        description: "Include desktop environment keybinds"
        checked: root.editShowDesktop
        onCheckedChanged: root.editShowDesktop = checked
    }

    NSwitch {
        Layout.fillWidth: true
        label: "Show Window Bindings"
        description: "Include window management keybinds"
        checked: root.editShowWindow
        onCheckedChanged: root.editShowWindow = checked
    }

    NSwitch {
        Layout.fillWidth: true
        label: "Show Launcher Bindings"
        description: "Include launcher keybinds"
        checked: root.editShowLauncher
        onCheckedChanged: root.editShowLauncher = checked
    }

    NLabel {
        text: "Requires niri to be installed with nirictl available in PATH."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        color: Color.mOnSurfaceVariant
    }
}