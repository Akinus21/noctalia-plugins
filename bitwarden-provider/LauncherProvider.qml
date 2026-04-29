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
    property bool bwAvailable: false
    property bool fetching: false
    property bool loaded: false
    property string sessionToken: ""

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        checkFlatpakInstalled()
    }

    function onOpened() {
        maybeRefresh()
    }

    function checkFlatpakInstalled() {
        flatpakInfoProc.running = true
    }

    Process {
        id: flatpakInfoProc
        command: ["flatpak", "info", "com.bitwarden.desktop"]

        onExited: {
            bwAvailable = exitCode === 0
            if (bwAvailable) {
                configureServer()
            }
        }
    }

    function configureServer() {
        var url = pluginApi?.pluginSettings?.serverUrl || ""
        if (!url) {
            Logger.w("BitwardenProvider", "No server URL configured")
            return
        }
        configCmd = ["flatpak", "run", "--command=bw", "com.bitwarden.desktop", "config", "server", url]
        configProc.running = true
    }

    property var configCmd: []

    Process {
        id: configProc
        command: configCmd

        onExited: {
            Logger.i("BitwardenProvider", "Server config exit:", exitCode)
            checkUnlockStatus()
        }
    }

    function checkUnlockStatus() {
        if (sessionToken) {
            statusCmd = ["sh", "-c", "flatpak run --command=bw com.bitwarden.desktop status --session " + sessionToken]
        } else {
            statusCmd = ["flatpak", "run", "--command=bw", "com.bitwarden.desktop", "status"]
        }
        statusProc.running = true
    }

    property var statusCmd: []

    Process {
        id: statusProc
        command: statusCmd

        onExited: {
            if (exitCode === 0) {
                try {
                    var status = JSON.parse(String(stdout))
                    unlocked = status.status === "unlocked"
                    if (unlocked && !loaded) {
                        loadItems()
                    }
                } catch (e) {
                    unlocked = false
                }
            } else {
                unlocked = false
            }
        }
    }

    function unlockVault() {
        var password = pluginApi?.pluginSettings?.password || ""
        var email = pluginApi?.pluginSettings?.email || ""
        if (!password || !email) {
            Logger.w("BitwardenProvider", "Missing email or password for unlock")
            return
        }
        var escapedPw = password.replace(/'/g, "'\\''")
        unlockCmd = ["sh", "-c", "BW_MASTER='" + escapedPw + "' flatpak run --env=BW_MASTER --command=bw com.bitwarden.desktop unlock --passwordenv BW_MASTER --raw"]
        unlockProc.running = true
    }

    property var unlockCmd: []

    Process {
        id: unlockProc
        command: unlockCmd

        onExited: {
            if (exitCode === 0) {
                sessionToken = stdout.trim()
                pluginApi.pluginSettings.sessionToken = sessionToken
                pluginApi.saveSettings()
                unlocked = true
                loadItems()
            }
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">bw")
    }

    function commands() {
        return [
            { "name": ">bitwarden", "description": "Search Bitwarden vault", "icon": "key", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden ") } },
            { "name": ">bw", "description": "Search Bitwarden vault", "icon": "key", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw ") } },
            { "name": ">bitwarden items", "description": "Browse all items", "icon": "list", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden items ") } },
            { "name": ">bw items", "description": "Browse all items", "icon": "list", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw items ") } },
            { "name": ">bitwarden username", "description": "Copy username for an item", "icon": "user", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden username ") } },
            { "name": ">bw username", "description": "Copy username for an item", "icon": "user", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw username ") } },
            { "name": ">bitwarden password", "description": "Copy password for an item", "icon": "lock", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bitwarden password ") } },
            { "name": ">bw password", "description": "Copy password for an item", "icon": "lock", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw password ") } }
        ]
    }

    function getResults(searchText) {
        var query = ""
        var mode = "search"

        if (searchText.startsWith(">bitwarden")) query = searchText.slice(10).trim()
        else if (searchText.startsWith(">bw")) query = searchText.slice(3).trim()
        else return []

        if (!bwAvailable) {
            return [{ "name": "Bitwarden Flatpak not found", "description": "com.bitwarden.desktop must be installed", "icon": "alert-circle", "isTablerIcon": true, "onActivate": function() {} }]
        }

        if (!unlocked) {
            return [{ "name": "Vault is locked", "description": "Configure email and password in plugin settings", "icon": "lock", "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
        }

        if (query.startsWith("username ")) { mode = "username"; query = query.slice(9).trim() }
        else if (query.startsWith("password ")) { mode = "password"; query = query.slice(9).trim() }
        else if (query === "items") { mode = "items"; query = "" }
        else if (query === "username") { mode = "username"; query = "" }
        else if (query === "password") { mode = "password"; query = "" }

        if (fetching) {
            return [{ "name": "Loading...", "description": "Fetching items", "icon": "loader", "isTablerIcon": true, "onActivate": function() {} }]
        }

        var pool = items
        var results = []

        if (query === "") {
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) results.push(makeResult(pool[i], mode))
        } else {
            var textQuery = query.toLowerCase()
            for (var j = 0; j < pool.length && results.length < 50; j++) {
                var item = pool[j]
                var haystack = ((item.name || "") + " " + (item.login ? item.login.username : "") + " " + (item.login ? item.login.uri : "")).toLowerCase()
                if (fuzzyMatch(textQuery, haystack)) results.push(makeResult(item, mode))
            }
        }

        if (results.length === 0 && loaded) {
            return [{ "name": "No items found", "description": "Try a different search term", "icon": "search-off", "isTablerIcon": true, "onActivate": function() {} }]
        }

        return results
    }

    function fuzzyMatch(needle, haystack) {
        if (needle === "") return true
        var ni = 0
        for (var hi = 0; hi < haystack.length && ni < needle.length; hi++) {
            if (haystack[hi] === needle[ni]) ni++
        }
        return ni === needle.length
    }

    function loadItems() {
        if (fetching || !sessionToken) return
        fetching = true
        loadCmd = ["sh", "-c", "flatpak run --command=bw com.bitwarden.desktop list items --session " + sessionToken]
        loadProc.running = true
    }

    property var loadCmd: []

    Process {
        id: loadProc
        command: loadCmd

        onExited: {
            fetching = false
            if (exitCode === 0) {
                try {
                    items = JSON.parse(String(stdout))
                    loaded = true
                    if (launcher) launcher.updateResults()
                    Logger.i("BitwardenProvider", "Loaded", items.length, "items")
                } catch (e) {
                    Logger.e("BitwardenProvider", "Parse error:", e)
                }
            } else {
                unlocked = false
            }
        }
    }

    function maybeRefresh() {
        if (!unlocked) checkUnlockStatus()
        else if (!loaded) loadItems()
    }

    function makeResult(item, mode) {
        var name = item.name || "Untitled"
        var subtitle = item.type || "login"

        if (mode === "username" && item.login && item.login.username) subtitle = item.login.username
        else if (mode === "password") subtitle = "Click to copy password"
        else if (mode === "items") {
            var u = item.login ? item.login.username : ""
            var uri = item.login ? item.login.uri : ""
            subtitle = u + (uri ? " - " + uri : "")
        } else if (item.login && item.login.username) subtitle = item.login.username

        return {
            "name": name, "description": subtitle, "icon": "key", "isTablerIcon": true, "provider": root,
            "onActivate": function() {
                if (mode === "username" && item.login && item.login.username) {
                    copyToClipboard(item.login.username)
                    ToastService.showNotice("Username copied")
                    launcher.close()
                } else if (mode === "password" && item.login && item.login.password) {
                    copyToClipboard(item.login.password)
                    ToastService.showNotice("Password copied")
                    launcher.close()
                } else {
                    openItemPanel(item)
                }
            }
        }
    }

    function openItemPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "view"
            pluginApi.pluginSettings._viewItem = item
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    function copyToClipboard(text) {
        var t = String(text).replace(/'/g, "'\\''")
        Quickshell.execDetached(["sh", "-c", "echo -n '" + t + "' | wl-copy"])
    }
}
