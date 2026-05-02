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
    property string bwPath: "/home/linuxbrew/.linuxbrew/bin/bw"

    // ── Process runner ────────────────────────────────────────────────────
    // Uses Quickshell's Process component so we get proper stdout/stderr
    // signals instead of polling a temp file.

    property string _pendingStdout: ""
    property var _pendingCallback: null

    Process {
        id: bwProcess

        property string collectedOutput: ""

        stdout: SplitParser {
            onRead: function(data) { bwProcess.collectedOutput += data + "\n" }
        }

        stderr: SplitParser {
            onRead: function(data) { Logger.w("BitwardenProvider", "stderr:", data) }
        }

        onExited: function(exitCode, exitStatus) {
            var out = bwProcess.collectedOutput.trim()
            Logger.d("BitwardenProvider", "Process exited code=" + exitCode + " output length=" + out.length)
            var cb = root._pendingCallback
            root._pendingCallback = null
            bwProcess.collectedOutput = ""
            if (cb) cb(out, exitCode)
        }
    }

    function runBw(args, cb) {
        if (bwProcess.running) {
            Logger.w("BitwardenProvider", "runBw: previous process still running, queuing is not supported — ignoring")
            return
        }
        _pendingCallback = cb
        bwProcess.collectedOutput = ""
        bwProcess.command = args
        bwProcess.running = true
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        Logger.i("BitwardenProvider", "Using bw path:", bwPath)
        checkStatus()
    }

    function onOpened() {
        if (!unlocked) checkStatus()
    }

    // ── Vault management ──────────────────────────────────────────────────

    function checkStatus() {
        if (bwProcess.running) return
        Logger.i("BitwardenProvider", "Checking vault status")
        runBw([bwPath, "status"], function(out, exitCode) {
            try {
                // bw status sometimes prints extra lines before the JSON
                var jsonStart = out.indexOf("{")
                if (jsonStart === -1) throw new Error("no JSON in output: " + out)
                var obj = JSON.parse(out.substring(jsonStart))
                vaultStatus = obj.status
                unlocked = (obj.status === "unlocked")
                Logger.i("BitwardenProvider", "Vault status:", vaultStatus)
                if (unlocked && !loaded) fetchItems()
            } catch (e) {
                vaultStatus = "unauthenticated"
                unlocked = false
                Logger.w("BitwardenProvider", "status parse error:", e, "raw output:", out)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function unlockVault() {
        if (bwProcess.running) return
        var password = pluginApi?.pluginSettings?.password || ""
        if (!password) {
            Logger.w("BitwardenProvider", "No password configured")
            return
        }
        Logger.i("BitwardenProvider", "Unlocking vault")

        // Pass password via env var to avoid shell quoting issues
        var env = Object.assign({}, Qt.application.environment)
        env["BW_PASSWORD"] = password
        bwProcess.environment = env

        runBw([bwPath, "unlock", "--passwordenv", "BW_PASSWORD", "--raw"], function(out, exitCode) {
            // Clear the env var immediately
            bwProcess.environment = {}

            var token = out.trim()
            Logger.i("BitwardenProvider", "Unlock result: exitCode=" + exitCode + " tokenLength=" + token.length)

            if (exitCode === 0 && token.length > 20) {
                sessionToken = token
                pluginApi.pluginSettings.sessionToken = token
                pluginApi.saveSettings()
                unlocked = true
                vaultStatus = "unlocked"
                fetchItems()
            } else {
                Logger.e("BitwardenProvider", "Unlock failed. exitCode=" + exitCode + " output:", out)
                vaultStatus = "locked"
                unlocked = false
            }
            if (launcher) launcher.updateResults()
        })
    }

    function fetchItems() {
        if (fetching || !sessionToken || bwProcess.running) return
        fetching = true
        Logger.i("BitwardenProvider", "Fetching vault items")
        runBw([bwPath, "list", "items", "--session", sessionToken], function(out, exitCode) {
            fetching = false
            if (exitCode !== 0 || !out) {
                Logger.e("BitwardenProvider", "list items failed. exitCode=" + exitCode)
                // Session may have expired — clear it
                if (exitCode !== 0) {
                    sessionToken = ""
                    unlocked = false
                    vaultStatus = "locked"
                    if (pluginApi) {
                        pluginApi.pluginSettings.sessionToken = ""
                        pluginApi.saveSettings()
                    }
                }
                if (launcher) launcher.updateResults()
                return
            }
            try {
                items = JSON.parse(out)
                loaded = true
                Logger.i("BitwardenProvider", "Loaded", items.length, "items")
            } catch (e) {
                Logger.e("BitwardenProvider", "JSON parse error:", e, "raw:", out.substring(0, 200))
            }
            if (launcher) launcher.updateResults()
        })
    }

    // ── Command handling ──────────────────────────────────────────────────

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">bw")
    }

    function commands() {
        return [
            { "name": ">bitwarden",          "description": "Search Bitwarden vault",       "icon": "key",      "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden ") } },
            { "name": ">bw",                 "description": "Search Bitwarden vault",       "icon": "key",      "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw ") } },
            { "name": ">bitwarden username", "description": "Copy username for an item",    "icon": "user",     "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden username ") } },
            { "name": ">bitwarden password", "description": "Copy password for an item",    "icon": "lock",     "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden password ") } },
            { "name": ">bitwarden settings", "description": "Open Bitwarden plugin settings","icon": "settings","isTablerIcon": true, "onActivate": function() { openSettings() } }
        ]
    }

    // ── Results ───────────────────────────────────────────────────────────

    function getResults(searchText) {
        var query = ""
        var mode  = "search"

        if      (searchText.startsWith(">bitwarden")) query = searchText.slice(10).trim()
        else if (searchText.startsWith(">bw"))        query = searchText.slice(3).trim()
        else return []

        if (query === "settings") { openSettings(); return [] }

        // bw not found guard
        if (bwPath === "") {
            return [{ "name": "bitwarden-cli not found", "description": "Install: brew install bitwarden-cli",
                      "icon": "alert-circle", "isTablerIcon": true, "onActivate": function() { openSettings() } }]
        }

        // Not unlocked
        if (!unlocked) {
            if (bwProcess.running) {
                return [{ "name": "Checking vault", "description": "Please wait", "icon": "loader", "isTablerIcon": true, "onActivate": function() {} }]
            }
            var hasCreds = !!(pluginApi?.pluginSettings?.password || "")
            if (hasCreds) {
                return [{ "name": "Vault locked — click to unlock", "description": "Uses credentials from settings",
                          "icon": "lock", "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
            }
            return [{ "name": "Not configured", "description": "Enter password in settings",
                      "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } }]
        }

        if (query.startsWith("username "))  { mode = "username"; query = query.slice(9).trim() }
        else if (query.startsWith("password ")) { mode = "password"; query = query.slice(9).trim() }
        else if (query === "username")      { mode = "username"; query = "" }
        else if (query === "password")      { mode = "password"; query = "" }

        if (fetching) {
            return [{ "name": "Loading vault", "description": "Fetching items", "icon": "loader", "isTablerIcon": true, "onActivate": function() {} }]
        }

        var pool = items
        var results = []

        if (query === "") {
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) results.push(makeResult(pool[i], mode))
        } else {
            var q = query.toLowerCase()
            for (var j = 0; j < pool.length && results.length < 50; j++) {
                var item  = pool[j]
                var uris  = (item.login && item.login.uris) ? item.login.uris : []
                var first = uris.length > 0 ? (uris[0].uri || "") : ""
                var hay   = ((item.name || "") + " " + (item.login ? (item.login.username || "") : "") + " " + first).toLowerCase()
                if (fuzzyMatch(q, hay)) results.push(makeResult(item, mode))
            }
        }

        if (results.length === 0 && loaded) {
            return [{ "name": "No items found", "description": "Try a different search", "icon": "search-off", "isTablerIcon": true, "onActivate": function() {} }]
        }

        return results
    }

    // ── Result builder ────────────────────────────────────────────────────

    function makeResult(item, mode) {
        var itemName = item.name || "Untitled"
        var username = item.login ? (item.login.username || "") : ""
        var password = item.login ? (item.login.password || "") : ""
        var subtitle = username || "No username"
        if (mode === "password") subtitle = password ? "Click to copy password" : "No password stored"

        return {
            "name": itemName, "description": subtitle, "icon": "key", "isTablerIcon": true, "provider": root,
            "onActivate": function() {
                if (mode === "username" && username) { copyToClipboard(username); if (launcher) launcher.close() }
                else if (mode === "password" && password) { copyToClipboard(password); if (launcher) launcher.close() }
                else { openItemPanel(item) }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    function fuzzyMatch(needle, haystack) {
        if (needle === "") return true
        var ni = 0
        for (var hi = 0; hi < haystack.length && ni < needle.length; hi++) {
            if (haystack[hi] === needle[ni]) ni++
        }
        return ni === needle.length
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + text.replace(/'/g, "'\''") + "' | wl-copy"])
    }

    function openItemPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "view"
            pluginApi.pluginSettings._viewItem  = item
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
