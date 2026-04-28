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
    property real contentPreferredWidth: 960 * Style.uiScaleRatio
    property real contentPreferredHeight: 800 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    property var keybinds: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    property string configPath: ""

    readonly property var niriActions: [
        "spawn", "close-window", "focus-window-or-workspace-down", "focus-window-or-workspace-up",
        "focus-column-left", "focus-column-right", "focus-column-first", "focus-column-last",
        "focus-window-down", "focus-window-up", "focus-window-down-or-column-left",
        "focus-window-down-or-column-right", "focus-window-up-or-column-left",
        "focus-window-up-or-column-right", "focus-window-or-workspace-left",
        "focus-window-or-workspace-right", "move-column-left", "move-column-right",
        "move-column-to-first", "move-column-to-last", "move-window-down", "move-window-up",
        "move-window-down-or-to-workspace-down", "move-window-up-or-to-workspace-up",
        "move-window-left", "move-window-right", "consume-or-expel-window-left",
        "consume-or-expel-window-right", "consume-window-into-column", "expel-window-from-column",
        "center-column", "focus-workspace", "focus-workspace-down", "focus-workspace-up",
        "focus-workspace-previous", "move-column-to-workspace", "move-column-to-workspace-down",
        "move-column-to-workspace-up", "move-window-to-workspace", "move-window-to-workspace-down",
        "move-window-to-workspace-up", "switch-preset-column-width", "switch-preset-window-height",
        "reset-window-height", "maximize-column", "fullscreen-window", "toggle-windowed-fullscreen",
        "screenshot", "screenshot-screen", "screenshot-window",
        "toggle-debug-tint", "debug-toggle-opaque-regions", "debug-toggle-damage",
        "quit", "power-off-monitors", "suspend", "toggle-overview",
        "set-column-width", "set-window-height", "move-workspace-down", "move-workspace-up",
        "allow-when-locked"
    ]

    readonly property var niriKeyNames: [
        "Mod", "Ctrl", "Alt", "Shift", "Super",
        "a","b","c","d","e","f","g","h","i","j","k","l","m",
        "n","o","p","q","r","s","t","u","v","w","x","y","z",
        "0","1","2","3","4","5","6","7","8","9",
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
        "Left","Right","Up","Down","Home","End","Page_Up","Page_Down",
        "Tab","Return","Escape","space","BackSpace","Delete","Insert",
        "XF86AudioRaiseVolume","XF86AudioLowerVolume","XF86AudioMute",
        "XF86AudioPlay","XF86AudioStop","XF86AudioNext","XF86AudioPrev",
        "XF86MonBrightnessUp","XF86MonBrightnessDown",
        "XF86PowerOff","Print","Pause","Scroll_Lock","Caps_Lock","Num_Lock",
        "minus","equal","bracketleft","bracketright","backslash",
        "semicolon","apostrophe","grave","comma","period","slash"
    ]

    Component.onCompleted: {
        configPath = getConfigPath()
        configFileView.path = configPath
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                ColumnLayout {
                    spacing: 2
                    NText {
                        text: "Niri Keybinds"
                        pointSize: Style.fontSizeXL
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                    }
                    NText {
                        text: configPath
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        elide: Text.ElideLeft
                        Layout.maximumWidth: 500
                    }
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Reload"
                    outlined: true
                    onClicked: {
                        loading = true
                        hasError = false
                        keybinds = []
                        configFileView.path = ""
                        configFileView.path = configPath
                    }
                }

                NButton {
                    text: "Open Config"
                    outlined: true
                    onClicked: Quickshell.execDetached(["xdg-open", configPath])
                }
            }

            NText {
                visible: loading
                text: "Loading config..."
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
            }

            NText {
                visible: hasError && !loading
                text: errorMessage
                color: Color.mError
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            NText {
                visible: !loading && !hasError && keybinds.length === 0
                text: "No keybinds found in config. Make sure your config has a binds { ... } block."
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !loading && !hasError && keybinds.length > 0

                ColumnLayout {
                    width: parent.width
                    spacing: Style.marginS

                    Repeater {
                        id: keybindRepeater
                        model: keybinds

                        NBox {
                            id: keybindRow
                            Layout.fillWidth: true
                            implicitHeight: rowContent.implicitHeight + Style.marginM * 2
                            radius: Style.radiusM

                            property bool keyPopupVisible: false
                            property bool actionPopupVisible: false
                            property var keyFiltered: []
                            property var actionFiltered: []

                            RowLayout {
                                id: rowContent
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    margins: Style.marginM
                                }
                                spacing: Style.marginM

                                Item {
                                    Layout.preferredWidth: 260
                                    implicitHeight: keyField.implicitHeight + (keybindRow.keyPopupVisible ? Math.min(keybindRow.keyFiltered.length, 6) * 32 : 0)

                                    NTextInput {
                                        id: keyField
                                        width: parent.width
                                        label: "Key Combo"
                                        placeholderText: "Mod+T"
                                        text: modelData.title || ""

                                        onTextChanged: {
                                            root.keybinds[index].title = text
                                            var q = text.toLowerCase()
                                            var parts = q.split("+")
                                            var last = parts[parts.length - 1]
                                            if (last.length > 0) {
                                                keybindRow.keyFiltered = root.niriKeyNames.filter(function(k) {
                                                    return k.toLowerCase().startsWith(last)
                                                }).slice(0, 8)
                                                keybindRow.keyPopupVisible = keybindRow.keyFiltered.length > 0
                                            } else {
                                                keybindRow.keyPopupVisible = false
                                            }
                                        }
                                        onActiveFocusChanged: {
                                            if (!activeFocus) keybindRow.keyPopupVisible = false
                                        }
                                    }

                                    Rectangle {
                                        id: keyPopup
                                        visible: keybindRow.keyPopupVisible
                                        anchors.top: keyField.bottom
                                        anchors.topMargin: 2
                                        width: parent.width
                                        height: Math.min(keybindRow.keyFiltered.length, 6) * 32
                                        color: Color.mSurface
                                        border.color: Color.mOutlineVariant
                                        radius: Style.radiusS
                                        z: 100

                                        ListView {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            model: keybindRow.keyFiltered
                                            clip: true

                                            delegate: Rectangle {
                                                width: parent.width
                                                height: 30
                                                color: suggestKeyMA.containsMouse ? Color.mSurfaceVariant : "transparent"
                                                radius: Style.radiusXS

                                                NText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: Style.marginS
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData
                                                    pointSize: Style.fontSizeS
                                                    color: Color.mOnSurface
                                                }

                                                MouseArea {
                                                    id: suggestKeyMA
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        var current = keyField.text
                                                        var plusIdx = current.lastIndexOf("+")
                                                        var prefix = plusIdx >= 0 ? current.substring(0, plusIdx + 1) : ""
                                                        keyField.text = prefix + modelData
                                                        keybindRow.keyPopupVisible = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: actionField.implicitHeight + (keybindRow.actionPopupVisible ? Math.min(keybindRow.actionFiltered.length, 6) * 32 : 0)

                                    NTextInput {
                                        id: actionField
                                        width: parent.width
                                        label: "Action"
                                        placeholderText: "spawn \"kitty\""
                                        text: modelData.bindings || ""

                                        onTextChanged: {
                                            root.keybinds[index].bindings = text
                                            var q = text.toLowerCase().split(";")[0].trim()
                                            if (q.length > 0) {
                                                keybindRow.actionFiltered = root.niriActions.filter(function(a) {
                                                    return a.toLowerCase().startsWith(q)
                                                }).slice(0, 8)
                                                keybindRow.actionPopupVisible = keybindRow.actionFiltered.length > 0
                                            } else {
                                                keybindRow.actionPopupVisible = false
                                            }
                                        }
                                        onActiveFocusChanged: {
                                            if (!activeFocus) keybindRow.actionPopupVisible = false
                                        }
                                    }

                                    Rectangle {
                                        id: actionPopup
                                        visible: keybindRow.actionPopupVisible
                                        anchors.top: actionField.bottom
                                        anchors.topMargin: 2
                                        width: parent.width
                                        height: Math.min(keybindRow.actionFiltered.length, 6) * 32
                                        color: Color.mSurface
                                        border.color: Color.mOutlineVariant
                                        radius: Style.radiusS
                                        z: 100

                                        ListView {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            model: keybindRow.actionFiltered
                                            clip: true

                                            delegate: Rectangle {
                                                width: parent.width
                                                height: 30
                                                color: suggestActionMA.containsMouse ? Color.mSurfaceVariant : "transparent"
                                                radius: Style.radiusXS

                                                NText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: Style.marginS
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData
                                                    pointSize: Style.fontSizeS
                                                    color: Color.mOnSurface
                                                }

                                                MouseArea {
                                                    id: suggestActionMA
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        actionField.text = modelData
                                                        keybindRow.actionPopupVisible = false
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                NButton {
                                    text: "\u2715"
                                    outlined: true
                                    Layout.preferredWidth: 44
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
                    text: "+ Add Keybind"
                    outlined: true
                    onClicked: {
                        var arr = root.keybinds.slice()
                        arr.push({ title: "", category: "General", bindings: "" })
                        root.keybinds = arr
                    }
                }

                NButton {
                    text: "Save"
                    visible: !loading && !hasError
                    onClicked: saveKeybinds()
                }

                Item { Layout.fillWidth: true }

                NText {
                    text: {
                        if (loading) return "Loading..."
                        if (hasError) return errorMessage
                        if (keybinds.length === 0) return "No keybinds"
                        return keybinds.length + " keybind" + (keybinds.length === 1 ? "" : "s")
                    }
                    color: hasError ? Color.mError : Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                }
            }
        }
    }

    FileView {
        id: configFileView
        watchChanges: false

        onLoaded: {
            Logger.i("NiriKeybinds", "Config loaded, bytes:", text().length)
            loading = false
            var result = parseKeybinds(text())
            if (result.length === 0) {
                Logger.w("NiriKeybinds", "Parser returned 0 keybinds - raw excerpt:", text().substring(0, 300))
            }
            keybinds = result
        }

        onLoadFailed: {
            loading = false
            hasError = true
            errorMessage = "Failed to load: " + configPath
            Logger.e("NiriKeybinds", "FileView load failed for path:", configPath)
        }
    }

    function getConfigPath() {
        var path = pluginApi?.pluginSettings?.configPath || ""
        if (path && path.length > 0) return path
        var home = Quickshell.env("HOME") || "/root"
        return home + "/.config/niri/config.kdl"
    }

    function parseKeybinds(content) {
        var bindings = []
        var src = String(content)

        var bindsStart = -1
        var searchFrom = 0
        while (searchFrom < src.length) {
            var idx = src.indexOf("binds", searchFrom)
            if (idx === -1) break
            var lineStart = src.lastIndexOf("\n", idx) + 1
            var linePrefix = src.substring(lineStart, idx).trim()
            if (linePrefix.startsWith("//") || linePrefix.startsWith("#")) {
                searchFrom = idx + 5
                continue
            }
            var braceIdx = src.indexOf("{", idx)
            if (braceIdx === -1) break
            bindsStart = braceIdx
            break
        }

        if (bindsStart === -1) {
            Logger.w("NiriKeybinds", "No 'binds {' block found in config")
            hasError = true
            errorMessage = "No 'binds { }' block found in config file."
            return []
        }

        var depth = 0
        var bindsEnd = -1
        for (var i = bindsStart; i < src.length; i++) {
            if (src[i] === "{") depth++
            else if (src[i] === "}") {
                depth--
                if (depth === 0) { bindsEnd = i; break }
            }
        }

        if (bindsEnd === -1) {
            Logger.w("NiriKeybinds", "binds block never closed")
            hasError = true
            errorMessage = "The 'binds { }' block is not properly closed."
            return []
        }

        var bindsBody = src.substring(bindsStart + 1, bindsEnd)
        Logger.i("NiriKeybinds", "binds body length:", bindsBody.length)

        var pos = 0
        var bodyLen = bindsBody.length

        while (pos < bodyLen) {
            while (pos < bodyLen && /\s/.test(bindsBody[pos])) pos++
            if (pos >= bodyLen) break

            if (bindsBody[pos] === "/" && bindsBody[pos + 1] === "/") {
                while (pos < bodyLen && bindsBody[pos] !== "\n") pos++
                continue
            }
            if (bindsBody[pos] === "#") {
                while (pos < bodyLen && bindsBody[pos] !== "\n") pos++
                continue
            }

            var stmtStart = pos
            var braceOpen = -1
            var tempPos = pos
            while (tempPos < bodyLen) {
                if (bindsBody[tempPos] === "{") { braceOpen = tempPos; break }
                if (bindsBody[tempPos] === "\n" && braceOpen === -1) {
                    break
                }
                tempPos++
            }

            if (braceOpen === -1) {
                while (pos < bodyLen && bindsBody[pos] !== "\n") pos++
                pos++
                continue
            }

            var keyCombo = bindsBody.substring(stmtStart, braceOpen).trim()

            if (keyCombo.indexOf("=") !== -1) {
                pos = braceOpen + 1
                continue
            }

            var bindDepth = 1
            var j = braceOpen + 1
            while (j < bodyLen && bindDepth > 0) {
                if (bindsBody[j] === "{") bindDepth++
                else if (bindsBody[j] === "}") bindDepth--
                j++
            }

            var actionBlock = bindsBody.substring(braceOpen + 1, j - 1)

            var actions = actionBlock.split(";")
                .map(function(s) { return s.replace(/\n/g, " ").trim() })
                .filter(function(s) {
                    return s.length > 0 && s !== "allow-when-locked=true" && !s.startsWith("//")
                })

            if (keyCombo.length > 0 && actions.length > 0) {
                bindings.push({
                    title: keyCombo,
                    category: "General",
                    bindings: actions.join("; ")
                })
            }

            pos = j
        }

        Logger.i("NiriKeybinds", "Parsed", bindings.length, "keybinds")
        return bindings
    }

    function deleteKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        var arr = keybinds.slice()
        arr.splice(index, 1)
        keybinds = arr
    }

    function saveKeybinds() {
        var proc = Quickshell.execDetached(["cat", configPath])
        proc.onCompleted.connect(function() {
            if (proc.exitCode !== 0) {
                ToastService.showError("Failed to read config for saving")
                return
            }
            var original = String(proc.readAll ? proc.readAll() : "")
            var updated = replaceBindsInConfig(original)
            var escaped = updated.replace(/'/g, "'\\''")
            Quickshell.execDetached(["sh", "-c",
                "cp '" + configPath + "' '" + configPath + ".backup' && " +
                "printf '%s' '" + escaped + "' > '" + configPath + "'"
            ])
            ToastService.showNotice("Keybinds saved (backup at " + configPath + ".backup)")
        })
    }

    function replaceBindsInConfig(original) {
        var src = String(original)

        var bindsStart = -1
        var searchFrom = 0
        while (searchFrom < src.length) {
            var idx = src.indexOf("binds", searchFrom)
            if (idx === -1) break
            var lineStart = src.lastIndexOf("\n", idx) + 1
            var linePrefix = src.substring(lineStart, idx).trim()
            if (linePrefix.startsWith("//") || linePrefix.startsWith("#")) {
                searchFrom = idx + 5
                continue
            }
            var braceIdx = src.indexOf("{", idx)
            if (braceIdx === -1) break
            bindsStart = idx
            break
        }

        if (bindsStart === -1) return original

        var braceIdx2 = src.indexOf("{", bindsStart)
        var depth = 0
        var bindsEnd = -1
        for (var i = braceIdx2; i < src.length; i++) {
            if (src[i] === "{") depth++
            else if (src[i] === "}") {
                depth--
                if (depth === 0) { bindsEnd = i; break }
            }
        }

        if (bindsEnd === -1) return original

        var newBlock = generateBindsSection()
        return src.substring(0, bindsStart) + newBlock + src.substring(bindsEnd + 1)
    }

    function generateBindsSection() {
        var lines = ["binds {"]
        for (var i = 0; i < keybinds.length; i++) {
            var kb = keybinds[i]
            if (kb.title && kb.bindings) {
                lines.push("    " + kb.title + " { " + kb.bindings + "; }")
            }
        }
        lines.push("}")
        return lines.join("\n")
    }
}
