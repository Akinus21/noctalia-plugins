import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: contentRect
    property real contentPreferredWidth: 900 * Style.uiScaleRatio
    property real contentPreferredHeight: 800 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    property var keybinds: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    property string configPath: ""

    Component.onCompleted: {
        configPath = getConfigPath()
        loadKeybinds()
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            NText {
                text: "Niri Keybinds"
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
            }

            NText {
                text: configPath
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Reload"
                    outlined: true
                    onClicked: {
                        loading = true
                        hasError = false
                        loadKeybinds()
                    }
                }

                NButton {
                    text: "Open Config"
                    outlined: true
                    onClicked: Quickshell.execDetached(["xdg-open", configPath])
                }
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200

                ColumnLayout {
                    width: parent.width
                    spacing: Style.marginM

                    Repeater {
                        model: keybinds

                        NBox {
                            Layout.fillWidth: true
                            implicitHeight: rowContent.implicitHeight + Style.marginM * 2 + 60
                            radius: Style.radiusM

                            RowLayout {
                                id: rowContent
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: Style.marginM
                                }
                                spacing: Style.marginM

                                NTextInput {
                                    Layout.preferredWidth: 240
                                    label: "Keybind"
                                    text: modelData.title || ""
                                }

                                NTextInput {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 500
                                    label: "Action"
                                    placeholderText: "action;"
                                    text: modelData.bindings || ""
                                }

                                NButton {
                                    text: "Delete"
                                    outlined: true
                                    Layout.preferredWidth: 80
                                    onClicked: deleteKeybind(index)
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Save"
                    onClicked: saveKeybinds()
                }

                Item { Layout.fillWidth: true }

                NText {
                    text: {
                        if (loading) return "Loading..."
                        if (hasError) return errorMessage
                        if (keybinds.length === 0) return "No keybinds found"
                        return keybinds.length + " keybinds"
                    }
                    color: hasError ? Color.mError : Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
            }
        }
    }

    function getConfigPath() {
        var path = pluginApi?.pluginSettings?.configPath || ""
        if (path) return path
        var home = Quickshell.env("HOME")
        if (!home) home = "/var/home/gabriel"
        return home + "/.config/niri/config.kdl"
    }

    function loadKeybinds() {
        loading = true
        hasError = false
        cacheFile.load()
    }

    FileView {
        id: cacheFile
        path: configPath
        watchChanges: false

        onLoaded: {
            Logger.i("NiriKeybinds", "FileView loaded, bytes:", text().length)
            loading = false
            parseKeybinds(text())
        }

        onLoadFailed: {
            loading = false
            hasError = true
            errorMessage = "Failed to load config"
        }
    }

    function parseKeybinds(content) {
        var bindings = []
        var lines = String(content).split("\n")
        var currentCategory = "General"

        Logger.i("NiriKeybinds", "parseKeybinds called, lines:", lines.length)

        var inBinds = false
        var braceCount = 0

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.startsWith("//") || line.startsWith("#")) {
                continue
            }

            if (line.includes("binds") && line.includes("{")) {
                inBinds = true
                braceCount = 1
                continue
            }

            if (inBinds) {
                for (var j = 0; j < line.length; j++) {
                    if (line[j] === "{") braceCount++
                    else if (line[j] === "}") braceCount--
                }

                if (braceCount === 0) {
                    inBinds = false
                    continue
                }

                if (braceCount > 0 && line.includes("=") && !line.includes("{")) {
                    continue
                }

                var keyMatch = line.match(/^([A-Za-z0-9+_]+)(?=\s)/)
                if (keyMatch) {
                    var keyCombo = keyMatch[1]
                    var action = extractAction(line)
                    if (keyCombo && action) {
                        bindings.push({
                            title: keyCombo,
                            category: currentCategory,
                            bindings: action
                        })
                    }
                }
            }
        }

        Logger.i("NiriKeybinds", "parsed keybinds:", bindings.length)
        keybinds = bindings
    }

    function extractAction(line) {
        var start = line.indexOf("{")
        var end = line.lastIndexOf("}")
        if (start === -1 || end === -1 || end <= start) return ""
        var actionBlock = line.substring(start + 1, end)
        var parts = actionBlock.split(";").map(function(s) { return s.trim() }).filter(function(s) { return s && s !== "allow-when-locked=true" })
        return parts.join(", ")
    }

    function deleteKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        keybinds.splice(index, 1)
        keybinds = keybinds
        saveKeybinds()
    }

    function saveKeybinds() {
        var content = generateConfig()
        Quickshell.execDetached(["sh", "-c", "cat > '" + configPath + "' << 'EOF'\n" + content + "\nEOF"])
    }

    function generateConfig() {
        var lines = []
        lines.push("binds {")

        for (var i = 0; i < keybinds.length; i++) {
            var kb = keybinds[i]
            lines.push("    " + kb.title + " { " + kb.bindings + "; }")
        }

        lines.push("}")
        return lines.join("\n")
    }
}
