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
            }
        ]
    }

    function getResults(searchText) {
        var query = ""
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
                "description": "Run 'bw unlock' first",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
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

        var results = []
        for (var i = 0; i < Math.min(items.length, 20); i++) {
            var item = items[i]
            results.push({
                "name": item.name || "Untitled",
                "description": item.login?.username || "",
                "icon": "user",
                "isTablerIcon": true,
                "provider": root,
                "onActivate": function() {}
            })
        }

        return results
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
}