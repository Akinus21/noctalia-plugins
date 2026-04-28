import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property var keybinds: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""

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
                if (pluginApi) {
                    pluginApi.pluginSettings._keybindCount = keybinds.length
                }
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

    function saveKeybinds() {
        var configPath = getConfigPath()
        var fileView = FileView.forPath(configPath)

        if (!fileView) {
            return
        }

        var newContent = generateConfigContent()
        fileView.writeAll(newContent)
        Logger.i("NiriKeybinds", "Saved keybinds to", configPath)
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
}