import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var launcher: null

    property string name: "Bitwarden Vault"
    property string supportedLayouts: "list"
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    property bool showsCategories: false
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({ "all": "key" })

    property var items: []
    property bool unlocked: false
    property bool fetching: false
    property bool loaded: false
    property string sessionToken: ""
    property string vaultStatus: "unauthenticated"
    property string bwPath: ""

    property string outFile: "/tmp/bw_out"
    FileView { id: outputFile; path: outFile }

    Timer {
        id: pollTimer
        interval: 1000
        repeat: false
        property var cb: null
        property int ticks: 0
        onTriggered: {
            ticks++
            var out = String(outputFile.content || "")
            if (ticks >= 60 || out.length > 0) {
                ticks = 0
                if (cb) cb(out)
            } else {
                pollTimer.restart()
            }
        }
    }

    function runBw(cmd, cb) {
        var env = 'export PATH="/home/linuxbrew/.linuxbrew/bin:/var/home/linuxbrew/.linuxbrew/bin:$HOME/.linuxbrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"'
        var full = env + " && " + cmd + " > " + outFile + " 2>&1"
        try {
            Quickshell.execDetached(["sh", "-c", full])
        } catch (e) {
            Logger.e("BitwardenProvider", "exec error:", e)
        }
        pollTimer.cb = cb
        pollTimer.restart()
    }

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        findBw()
    }

    function onOpened() {
        if (!unlocked && bwPath !== "") checkStatus()
    }

    function findBw() {
        var cmd = "brew --prefix bitwarden-cli 2>/dev/null"
        runBw(cmd, function(out) {
            var prefix = out.trim()
            if (prefix && prefix.indexOf("/") >= 0 && prefix.indexOf("Error") < 0) {
                bwPath = prefix + "/bin/bw"
                Logger.i("BitwardenProvider", "bw found via brew:", bwPath)
                checkStatus()
            } else {
                findBwFallback()
            }
            if (launcher) launcher.updateResults()
        })
    }

    function findBwFallback() {
        var cmd = 'for p in /home/linuxbrew/.linuxbrew/bin/bw /var/home/linuxbrew/.linuxbrew/bin/bw "$HOME/.linuxbrew/bin/bw" "$HOME/.local/bin/bw" /usr/local/bin/bw /usr/bin/bw; do [ -f "$p" ] && echo "$p" && exit 0; done; echo NOTFOUND'
        runBw(cmd, function(out) {
            var found = out.trim()
            if (found && found !== "NOTFOUND") {
                bwPath = found
                Logger.i("BitwardenProvider", "bw found at fallback path:", bwPath)
                checkStatus()
            } else {
                bwPath = ""
                Logger.w("BitwardenProvider", "bw not found via brew or fallback paths")
            }
            if (launcher) launcher.updateResults()
        })
    }

    function checkStatus() {
        if (bwPath === "") return
        runBw(bwPath + " status", function(out) {
            try {
                var obj = JSON.parse(out.trim())
                vaultStatus = obj.status
                unlocked = (obj.status === "unlocked")
                Logger.i("BitwardenProvider", "vault:", vaultStatus)
                if (unlocked && !loaded) fetchItems()
            } catch (e) {
                vaultStatus = "unauthenticated"
                unlocked = false
                Logger.w("BitwardenProvider", "status parse error:", out)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function unlockVault() {
        if (bwPath === "") return
        var password = pluginApi?.pluginSettings?.password || ""
        if (!password) return
        Logger.i("BitwardenProvider", "unlocking...")
        var cmd = "BW_PASSWORD='" + password.replace(/'/g, "'\\''") + "' " + bwPath + " unlock --passwordenv BW_PASSWORD --raw"
        runBw(cmd, function(out) {
            var token = out.trim()
            Logger.i("BitwardenProvider", "unlock token:", token ? "got token (" + token.length + " chars)" : "empty")
            if (token.length > 20) {
                sessionToken = token
                pluginApi.pluginSettings.sessionToken = token
                pluginApi.saveSettings()
                unlocked = true
                vaultStatus = "unlocked"
                fetchItems()
            } else {
                Logger.e("BitwardenProvider", "unlock failed:", token)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function fetchItems() {
        if (fetching || !sessionToken || bwPath === "") return
        fetching = true
        runBw(bwPath + " list items --session '" + sessionToken.replace(/'/g, "'\\''") + "'", function(out) {
            fetching = false
            if (!out) {
                unlocked = false
                vaultStatus = "locked"
                if (launcher) launcher.updateResults()
                return
            }
            try {
                items = JSON.parse(out.trim())
                loaded = true
                Logger.i("BitwardenProvider", "Loaded", items.length, "items")
            } catch (e) {
                Logger.e("BitwardenProvider", "parse error:", e, "raw:", out.substring(0, 100))
            }
            if (launcher) launcher.updateResults()
        })
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">bw")
    }

    function commands() {
        return [
            { "name": ">bitwarden", "description": "Search Bitwarden vault", "icon": "key", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden ") } },
            { "name": ">bw", "description": "Search Bitwarden vault", "icon": "key", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw ") } },
            { "name": ">bitwarden username", "description": "Copy username for an item", "icon": "user", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden username ") } },
            { "name": ">bitwarden password", "description": "Copy password for an item", "icon": "lock", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden password ") } },
            { "name": ">bitwarden settings", "description": "Open Bitwarden plugin settings", "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } }
        ]
    }

    function getResults(searchText) {
        var query = ""
        var mode = "search"

        if (searchText.startsWith(">bitwarden")) query = searchText.slice(10).trim()
        else if (searchText.startsWith(">bw")) query = searchText.slice(3).trim()
        else return []

        if (query === "settings") { openSettings(); return [] }

        if (bwPath === "") {
            return [
                { "name": "bitwarden-cli not found", "description": "Install: brew install bitwarden-cli", "icon": "alert-circle", "isTablerIcon": true,
                  "onActivate": function() { openSettings() } }
            ]
        }

        if (!unlocked) {
            var hasCreds = !!(pluginApi?.pluginSettings?.password || "")
            if (hasCreds) {
                return [{ "name": "Vault locked - click to unlock", "description": "Uses credentials from settings", "icon": "lock", "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
            }
            return [{ "name": "Not configured", "description": "Enter password in settings", "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } }]
        }

        if (query.startsWith("username ")) { mode = "username"; query = query.slice(9).trim() }
        else if (query.startsWith("password ")) { mode = "password"; query = query.slice(9).trim() }
        else if (query === "username") { mode = "username"; query = "" }
        else if (query === "password") { mode = "password"; query = "" }

        if (fetching) {
            return [{ "name": "Loading vault...", "description": "Fetching items", "icon": "loader", "isTablerIcon": true }]
        }

        var pool = items
        var results = []

        if (query === "") {
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) results.push(makeResult(pool[i], mode))
        } else {
            var q = query.toLowerCase()
            for (var j = 0; j < pool.length && results.length < 50; j++) {
                var item = pool[j]
                var haystack = ((item.name || "") + " " + (item.login ? (item.login.username || "") : "") + " " + (item.login && item.login.uris ? (item.login.uris[0]?.uri || "") : "")).toLowerCase()
                if (fuzzyMatch(q, haystack)) results.push(makeResult(item, mode))
            }
        }

        if (results.length === 0 && loaded) {
            return [{ "name": "No items found", "description": "Try a different search", "icon": "search-off", "isTablerIcon": true }]
        }

        return results
    }

    function makeResult(item, mode) {
        var itemName = item.name || "Untitled"
        var username = item.login ? (item.login.username || "") : ""
        var password = item.login ? (item.login.password || "") : ""
        var subtitle = username || "No username"
        if (mode === "password") subtitle = password ? "Click to copy password" : "No password stored"

        return {
            "name": itemName, "description": subtitle, "icon": "key", "isTablerIcon": true, "provider": root,
            "onActivate": function() {
                if (mode === "username" && username) { copyToClipboard(username); launcher.close() }
                else if (mode === "password" && password) { copyToClipboard(password); launcher.close() }
                else { openItemPanel(item) }
            }
        }
    }

    function fuzzyMatch(needle, haystack) {
        if (needle === "") return true
        var ni = 0
        for (var hi = 0; hi < haystack.length && ni < needle.length; hi++) {
            if (haystack[hi] === needle[ni]) ni++
        }
        return ni === needle.length
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + text.replace(/'/g, "'\\''") + "' | wl-copy"])
    }

    function openItemPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "view"
            pluginApi.pluginSettings._viewItem = item
            pluginApi.openPanel(screen)
        })
        if (launcher) launcher.close()
    }

    function openSettings() {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            BarService.openPluginSettings(screen, pluginApi.manifest)
        })
        if (launcher) launcher.close()
    }
}
