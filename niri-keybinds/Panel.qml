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
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 500 * Style.uiScaleRatio
    property real contentPreferredHeight: 600 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    property var keybinds: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""

    Component.onCompleted: {
        loadKeybinds()
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginM

            NLabel {
                text: "Niri Keybinds"
                font.bold: true
                font.pixelSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Reload"
                    outlined: true
                    onClicked: loadKeybinds()
                }

                NButton {
                    text: "Save Changes"
                    outlined: true
                    onClicked: saveKeybinds()
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Open Config"
                    outlined: true
                    onClicked: openConfigFile()
                }
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginS

                    Repeater {
                        model: keybinds

                        NBox {
                            Layout.fillWidth: true
                            padding: Style.marginM
                            radius: Style.radiusM

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Style.marginS

                                RowLayout {
                                    Layout.fillWidth: true

                                    NLabel {
                                        text: modelData.title || "Unnamed"
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    NLabel {
                                        text: modelData.category || ""
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                NLabel {
                                    text: modelData.bindings || ""
                                    color: Color.mPrimary
                                    font.family: "monospace"
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    NButton {
                                        text: "Edit"
                                        outlined: true
                                        onClicked: editKeybind(index)
                                    }

                                    NButton {
                                        text: "Delete"
                                        outlined: true
                                        onClicked: deleteKeybind(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            NLabel {
                text: hasError ? errorMessage : (keybinds.length + " keybinds loaded")
                color: hasError ? Color.mError : Color.mOnSurfaceVariant
                font.pixelSize: Style.fontSizeS
                Layout.fillWidth: true
            }
        }
    }

    function getConfigPath() {
        var path = pluginApi?.pluginSettings?.configPath || ""
        if (path) return path
        return Quickshell.env("HOME") + "/.config/niri/config.kdl"
    }

    function loadKeybinds() {
        loading = true
        hasError = false

        var configPath = getConfigPath()
        var proc = Quickshell.execDetached(["sh", "-c", "nirictl keybinds 2>/dev/null || cat " + configPath])

        proc.onCompleted.connect(function() {
            loading = false
            if (proc.exitCode === 0) {
                parseKeybinds(proc.readAll())
            } else {
                hasError = true
                errorMessage = "Failed to load keybinds. Is niri installed?"
                Logger.e("NiriKeybinds", "Failed to load keybinds:", proc.exitCode)
            }
        })
    }

    function parseKeybinds(content) {
        var bindings = []
        var lines = String(content).split("\n")
        var currentCategory = ""

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.startsWith("//") || line.startsWith("#")) {
                if (line.toLowerCase().includes("desktop") || line.toLowerCase().includes("window")) {
                    currentCategory = line.replace(/^[\/#\s]+/g, "").trim()
                }
                continue
            }

            var keybindMatch = line.match(/^keybind\s+(?:(?:"([^"]+)")|(\S+))\s*\{/)
            if (keybindMatch) {
                var title = keybindMatch[1] || keybindMatch[2] || ""
                var bindings_str = extractBindings(lines, i, title)

                if (bindings_str) {
                    bindings.push({
                        title: title,
                        category: currentCategory || "General",
                        bindings: bindings_str,
                        originalLine: line
                    })
                }
            }
        }

        keybinds = bindings
        Logger.i("NiriKeybinds", "Loaded", bindings.length, "keybinds")
    }

    function extractBindings(lines, startIndex, title) {
        var bindings = []
        var braceCount = 0
        var foundTitle = false

        for (var i = startIndex; i < lines.length; i++) {
            var line = lines[i]

            for (var j = 0; j < line.length; j++) {
                if (line[j] === "{") braceCount++
                else if (line[j] === "}") braceCount--
            }

            var keyMatch = line.match(/^\s*key\s+(?:(?:"([^"]+)")|(\S+))/)
            if (keyMatch) {
                var key = keyMatch[1] || keyMatch[2]
                if (key && key !== "undefined") {
                    bindings.push(key)
                }
            }

            if (braceCount === 0 && foundTitle) break
            if (line.includes(title)) foundTitle = true
        }

        return bindings.join(", ")
    }

    function editKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        var keybind = keybinds[index]
        pluginApi.pluginSettings._editIndex = index
        pluginApi.pluginSettings._editKeybind = keybind
        pluginApi.openPanel(pluginApi.panelOpenScreen)
    }

    function deleteKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        keybinds.splice(index, 1)
        keybinds = keybinds
        saveKeybinds()
    }

    function saveKeybinds() {
        var configPath = getConfigPath()
        var fileView = FileView.forPath(configPath)

        if (!fileView) {
            ToastService.showError("Cannot open config file")
            return
        }

        var newContent = generateConfigContent()
        fileView.writeAll(newContent)

        ToastService.showNotice("Keybinds saved to " + configPath)
    }

    function generateConfigContent() {
        var lines = []
        lines.push("// Niri Keybinds Configuration")
        lines.push("")

        var byCategory = {}
        for (var i = 0; i < keybinds.length; i++) {
            var kb = keybinds[i]
            var cat = kb.category || "General"
            if (!byCategory[cat]) byCategory[cat] = []
            byCategory[cat].push(kb)
        }

        for (var cat in byCategory) {
            lines.push("// " + cat)
            var items = byCategory[cat]
            for (var j = 0; j < items.length; j++) {
                var kb = items[j]
                lines.push("keybind \"" + kb.title + "\" {")
                var keys = kb.bindings.split(", ")
                for (var k = 0; k < keys.length; k++) {
                    lines.push("    key \"" + keys[k] + "\"")
                }
                lines.push("}")
                lines.push("")
            }
        }

        return lines.join("\n")
    }

    function openConfigFile() {
        var configPath = getConfigPath()
        Quickshell.execDetached(["xdg-open", configPath])
    }
}