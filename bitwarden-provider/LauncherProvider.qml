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
    property string vaultStatus: "locked"

    property string outDir: "/var/home/gabriel/.cache/noctalia"

    FileView {
        id: tokenFile
        path: outDir + "/bw_token"
    }

    FileView {
        id: statusFile
        path: outDir + "/bw_status"
    }

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        flatpakInfoProc.command = ["flatpak", "info", "com.bitwarden.desktop"]
        flatpakInfoProc.running = true
    }

    function onOpened() {
        maybeRefresh()
    }

    Process {
        id: flatpakInfoProc
        command: []

        onExited: function(exitCode) {
            bwAvailable = exitCode === 0
            if (bwAvailable) {
                setupServer()
            }
        }
    }

    function setupServer() {
        var url = pluginApi?.pluginSettings?.serverUrl || ""
        if (!url) {
            checkUnlockStatus()
            return
        }
        var script = "#!/bin/bash\nmkdir -p " + outDir + "\nflatpak run --command=bw com.bitwarden.desktop config server " + JSON.stringify(url) + " 2>&1\n"
        writeAndRun(script, function() { checkUnlockStatus() })
    }

    function checkUnlockStatus() {
        Logger.i("BitwardenProvider", "checkUnlockStatus, token:", sessionToken ? "present" : "empty")
        var script
        if (sessionToken) {
            script = "#!/bin/bash\nmkdir -p " + outDir + "\nflatpak run --command=bw com.bitwarden.desktop status --session " + sessionToken + " > " + outDir + "/bw_status 2>&1\n"
        } else {
            script = "#!/bin/bash\nmkdir -p " + outDir + "\nflatpak run --command=bw com.bitwarden.desktop status > " + outDir + "/bw_status 2>&1\n"
        }
        writeAndRun(script, function() {
            var out = String(statusFile.content || "").trim()
            Logger.i("BitwardenProvider", "status output:", out)
            try {
                var s = JSON.parse(out).status
                vaultStatus = s
                unlocked = (s === "unlocked")
                if (unlocked && !loaded) loadItems()
            } catch (e) {
                vaultStatus = "unauthenticated"
                unlocked = false
            }
        })
    }

    function unlockVault() {
        var password = pluginApi?.pluginSettings?.password || ""
        var email = pluginApi?.pluginSettings?.email || ""
        if (!password) return

        Logger.i("BitwardenProvider", "unlockVault - status:", vaultStatus, "pw len:", password.length)
        var script
        if (vaultStatus === "unauthenticated") {
            if (!email) return
            script = "#!/bin/bash\nmkdir -p " + outDir + "\nprintf '%s\\n' " + JSON.stringify(password) + " | flatpak run --command=bw com.bitwarden.desktop login " + JSON.stringify(email) + " --raw > " + outDir + "/bw_token 2>&1\n"
        } else {
            script = "#!/bin/bash\nmkdir -p " + outDir + "\nprintf '%s\\n' " + JSON.stringify(password) + " | flatpak run --command=bw com.bitwarden.desktop unlock --raw > " + outDir + "/bw_token 2>&1\n"
        }
        writeAndRun(script, function() {
            var token = String(tokenFile.content || "").trim()
            Logger.i("BitwardenProvider", "login/unlock token len:", token.length)
            if (token) {
                sessionToken = token
                pluginApi.pluginSettings.sessionToken = sessionToken
                pluginApi.saveSettings()
                unlocked = true
                vaultStatus = "unlocked"
                loadItems()
            } else {
                Logger.e("BitwardenProvider", "Login/unlock failed")
            }
        })
    }

    Timer {
        id: pollTimer
        interval: 500
        repeat: false
        property var callback: null
        onTriggered: {
            if (callback) callback()
        }
    }

    function writeAndRun(scriptContent, cb) {
        try {
            Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(scriptContent) + " > " + outDir + "/script.sh && chmod +x " + outDir + "/script.sh && " + outDir + "/script.sh"])
        } catch (e) {
            Logger.e("BitwardenProvider", "execDetached error:", e)
        }
        pollTimer.callback = cb
        pollTimer.restart()
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
            { "name": ">bitwarden settings", "description": "Open Bitwarden settings", "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } },
            { "name": ">bw password", "description": "Copy password for an item", "icon": "lock", "isTablerIcon": true, "onActivate": function() { launcher.setSearchText(">bw password ") } }
        ]
    }

    function getResults(searchText) {
        var query = ""
        var mode = "search"

        if (searchText.startsWith(">bitwarden")) query = searchText.slice(10).trim()
        else if (searchText.startsWith(">bw")) {
            var bwQuery = searchText.slice(3).trim()
            if (bwQuery === "settings") { openSettings(); return [] }
            query = bwQuery
        }
        else return []

        if (!bwAvailable) {
            return [{ "name": "Bitwarden Flatpak not found", "description": "com.bitwarden.desktop must be installed", "icon": "alert-circle", "isTablerIcon": true }]
        }

        if (!unlocked) {
            var hasCreds = (pluginApi?.pluginSettings?.email || "") && (pluginApi?.pluginSettings?.password || "")
            if (hasCreds) {
                if (vaultStatus === "unauthenticated") {
                    return [{ "name": "Not logged in", "description": "Click to login", "icon": "login", "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
                }
                return [{ "name": "Vault is locked", "description": "Click to unlock", "icon": "lock", "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
            } else {
                return [{ "name": "Not configured", "description": "Click to open plugin settings", "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } }]
            }
        }

        if (query.startsWith("username ")) { mode = "username"; query = query.slice(9).trim() }
        else if (query.startsWith("password ")) { mode = "password"; query = query.slice(9).trim() }
        else if (query === "items") { mode = "items"; query = "" }
        else if (query === "username") { mode = "username"; query = "" }
        else if (query === "password") { mode = "password"; query = "" }
        else if (query === "settings") { openSettings(); return [] }

        if (fetching) {
            return [{ "name": "Loading...", "description": "Fetching items", "icon": "loader", "isTablerIcon": true }]
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
            return [{ "name": "No items found", "description": "Try a different search term", "icon": "search-off", "isTablerIcon": true }]
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
        var script = "#!/bin/bash\nmkdir -p " + outDir + "\nflatpak run --command=bw com.bitwarden.desktop list items --session " + sessionToken + " > " + outDir + "/bw_token 2>&1\n"
        writeAndRun(script, function() {
            fetching = false
            var data = String(tokenFile.content || "").trim()
            if (data) {
                try {
                    items = JSON.parse(data)
                    loaded = true
                    if (launcher) launcher.updateResults()
                    Logger.i("BitwardenProvider", "Loaded", items.length, "items")
                } catch (e) {
                    Logger.e("BitwardenProvider", "Parse error:", e)
                }
            } else {
                unlocked = false
            }
        })
    }

    function maybeRefresh() {
        checkUnlockStatus()
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

    function openSettings() {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            BarService.openPluginSettings(screen, pluginApi.manifest)
        })
        launcher.close()
    }

    function copyToClipboard(text) {
        var t = String(text).replace(/'/g, "'\\''")
        Quickshell.execDetached(["sh", "-c", "echo -n '" + t + "' | wl-copy"])
    }
}