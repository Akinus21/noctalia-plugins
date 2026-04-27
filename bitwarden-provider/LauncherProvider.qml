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

    property string vaultUrl: ""

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        vaultUrl = pluginApi?.pluginSettings?.vaultUrl || ""
        checkBwInstalled()
    }

    function onOpened() {
        maybeRefresh()
    }

    function checkBwInstalled() {
        var proc = Quickshell.execDetached(["which", "bw"])
        proc.onCompleted: {
            if (proc.exitCode === 0) {
                bwAvailable = true
                pluginApi.pluginSettings.bwAvailable = true
                Logger.i("BitwardenProvider", "bw CLI found")
                checkUnlockStatus()
            } else {
                bwAvailable = false
                pluginApi.pluginSettings.bwAvailable = false
                Logger.w("BitwardenProvider", "bw CLI not found")
            }
        }
    }

    function checkUnlockStatus() {
        var proc = Quickshell.execDetached(["bw", "status"])
        proc.onCompleted: {
            try {
                var output = proc.readAll()
                var status = JSON.parse(String(output))
                if (status.status === "unlocked") {
                    unlocked = true
                    sessionToken = status.token || ""
                    loadItems()
                } else {
                    unlocked = false
                    sessionToken = ""
                }
            } catch (e) {
                unlocked = false
            }
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">bw")
    }

    function commands() {
        return [
            {
                "name": ">bitwarden",
                "description": "Search Bitwarden vault",
                "icon": "key",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden ") }
            },
            {
                "name": ">bw",
                "description": "Search Bitwarden vault",
                "icon": "key",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw ") }
            },
            {
                "name": ">bitwarden items",
                "description": "Browse all items",
                "icon": "list",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden items ") }
            },
            {
                "name": ">bw items",
                "description": "Browse all items",
                "icon": "list",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw items ") }
            },
            {
                "name": ">bitwarden username",
                "description": "Copy username for an item",
                "icon": "user",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden username ") }
            },
            {
                "name": ">bw username",
                "description": "Copy username for an item",
                "icon": "user",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw username ") }
            },
            {
                "name": ">bitwarden password",
                "description": "Copy password for an item",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden password ") }
            },
            {
                "name": ">bw password",
                "description": "Copy password for an item",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw password ") }
            }
        ]
    }

    function getResults(searchText) {
        var query = ""
        var mode = "search"

        if (searchText.startsWith(">bitwarden")) {
            query = searchText.slice(10).trim()
        } else if (searchText.startsWith(">bw")) {
            query = searchText.slice(3).trim()
        } else {
            return []
        }

        if (!bwAvailable) {
            return [{
                "name": "Bitwarden CLI not installed",
                "description": "Install from bitwarden.com/download",
                "icon": "alert-circle",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
        }

        if (!unlocked) {
            return [{
                "name": "Vault is locked",
                "description": "Run bw unlock first or add session token in settings",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
        }

        if (query.startsWith("username ")) {
            mode = "username"
            query = query.slice(9).trim()
        } else if (query.startsWith("password ")) {
            mode = "password"
            query = query.slice(9).trim()
        } else if (query === "items") {
            mode = "items"
            query = ""
        } else if (query === "username") {
            mode = "username"
            query = ""
        } else if (query === "password") {
            mode = "password"
            query = ""
        }

        if (fetching) {
            return [{
                "name": "Loading...",
                "description": "Fetching items",
                "icon": "loader",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
        }

        var pool = items
        var results = []

        if (query === "") {
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) {
                results.push(makeResult(pool[i], mode))
            }
        } else {
            var textQuery = query.toLowerCase()
            for (var i = 0; i < pool.length && results.length < 50; i++) {
                var item = pool[i]
                var haystack = ((item.name || "") + " " + (item.login?.username || "") + " " + (item.login?.uri || "")).toLowerCase()
                if (fuzzyMatch(textQuery, haystack)) {
                    results.push(makeResult(item, mode))
                }
            }
        }

        if (results.length === 0 && loaded) {
            return [{
                "name": "No items found",
                "description": "Try a different search term",
                "icon": "search-off",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
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

        var proc = Quickshell.execDetached(["bw", "list", "items", "--sessionid", sessionToken])
        proc.onCompleted: {
            fetching = false
            if (proc.exitCode === 0) {
                try {
                    var output = proc.readAll()
                    items = JSON.parse(String(output))
                    loaded = true
                    if (launcher) launcher.updateResults()
                    Logger.i("BitwardenProvider", "Loaded", items.length, "items")
                } catch (e) {
                    Logger.e("BitwardenProvider", "Parse error:", e)
                }
            } else {
                Logger.e("BitwardenProvider", "Failed to list items:", proc.exitCode)
                unlocked = false
            }
        }
    }

    function maybeRefresh() {
        if (sessionToken && !unlocked) {
            checkUnlockStatus()
        } else if (unlocked && !loaded) {
            loadItems()
        }
    }

    function makeResult(item, mode) {
        var name = item.name || "Untitled"
        var subtitle = item.type || "login"

        if (mode === "username" && item.login?.username) {
            subtitle = item.login.username
        } else if (mode === "password") {
            subtitle = "Click to copy password"
        } else if (mode === "items") {
            subtitle = (item.login?.username || "") + (item.login?.uri ? " - " + item.login.uri : "")
        } else if (item.login?.username) {
            subtitle = item.login.username
        }

        return {
            "name": name,
            "description": subtitle,
            "icon": "key",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                if (mode === "username" && item.login?.username) {
                    copyToClipboard(item.login.username)
                    ToastService.showNotice("Username copied")
                    launcher.close()
                } else if (mode === "password" && item.login?.password) {
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
        Quickshell.execDetached(["sh", "-c", "echo -n '" + String(text).replace(/'/g, "'\\''") + "' | wl-copy"])
    }
}