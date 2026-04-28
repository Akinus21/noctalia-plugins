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
    property real contentPreferredWidth: 500 * Style.uiScaleRatio
    property real contentPreferredHeight: 600 * Style.uiScaleRatio
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
                    onClicked: loadKeybinds()
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

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginS

                    Repeater {
                        model: keybinds

                        NBox {
                            Layout.fillWidth: true
                            radius: Style.radiusM

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Style.marginM
                                spacing: Style.marginS

                                RowLayout {
                                    Layout.fillWidth: true

                                    NText {
                                        text: modelData.title || "Unnamed"
                                        font.weight: Font.Bold
                                    }

                                    NText {
                                        text: modelData.category || ""
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                NText {
                                    text: modelData.bindings || ""
                                    color: Color.mPrimary
                                    font.family: "monospace"
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

    function getConfigPath() {
        var path = pluginApi?.pluginSettings?.configPath || ""
        if (path) return path
        return Quickshell.env("HOME") + "/.config/niri/config.kdl"
    }

    function loadKeybinds() {
        loading = true
        hasError = false

        var proc = Quickshell.execDetached(["cat", configPath])

        if (!proc) {
            loading = false
            hasError = true
            errorMessage = "Failed to start process"
            return
        }

        proc.onCompleted.connect(function() {
            loading = false
            if (proc.exitCode === 0) {
                parseKeybinds(proc.readAll())
            } else {
                hasError = true
                errorMessage = "Failed to read config"
            }
        })

        proc.onError.connect(function(err) {
            loading = false
            hasError = true
            errorMessage = "Process error: " + err
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

            if (line.startsWith("keybind")) {
                var match = line.match(/^keybind\s+(?:(?:"([^"]+)")|(\S+))\s*\{/)
                if (match) {
                    var title = match[1] || match[2] || ""
                    var keys = extractKeys(lines, i)
                    if (keys) {
                        bindings.push({
                            title: title,
                            category: currentCategory || "General",
                            bindings: keys
                        })
                    }
                }
            }
        }

        keybinds = bindings
    }

    function extractKeys(lines, startIndex) {
        var keys = []
        var braceCount = 0

        for (var i = startIndex; i < lines.length && braceCount >= 0; i++) {
            var line = lines[i]
            for (var j = 0; j < line.length; j++) {
                if (line[j] === "{") braceCount++
                else if (line[j] === "}") braceCount--
            }

            var keyMatch = line.match(/^\s*key\s+(?:(?:"([^"]+)")|(\S+))/)
            if (keyMatch) {
                var key = keyMatch[1] || keyMatch[2]
                if (key && key !== "undefined") keys.push(key)
            }
        }

        return keys.join(", ")
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
        lines.push("// Niri Keybinds")

        var byCat = {}
        for (var i = 0; i < keybinds.length; i++) {
            var kb = keybinds[i]
            var cat = kb.category || "General"
            if (!byCat[cat]) byCat[cat] = []
            byCat[cat].push(kb)
        }

        for (var cat in byCat) {
            lines.push("// " + cat)
            var items = byCat[cat]
            for (var j = 0; j < items.length; j++) {
                var kb = items[j]
                lines.push("keybind \"" + kb.title + "\" {")
                var keys = kb.bindings.split(", ")
                for (var k = 0; k < keys.length; k++) {
                    lines.push("    key \"" + keys[k].trim() + "\"")
                }
                lines.push("}")
            }
        }

        return lines.join("\n")
    }
}