import QtQuick
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
    property string serverUrl: "http://localhost:8087"
    property string serverRunning: false

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        checkServer()
    }

    function onOpened() {
        if (!unlocked && serverRunning) checkStatus()
    }

    function checkServer() {
        Logger.d("BitwardenProvider", "Checking bw serve at", serverUrl)
        bwRequest("GET", "/status", null, function(resp, success) {
            if (success) {
                Logger.i("BitwardenProvider", "bw serve responding")
                serverRunning = true
                try {
                    var data = JSON.parse(resp)
                    var stat = data.data?.status || data.status || "unknown"
                    unlocked = (stat === "unlocked")
                    if (unlocked && !loaded) fetchItems()
                } catch (e) {}
            } else {
                Logger.w("BitwardenProvider", "bw serve not responding:", resp)
                serverRunning = false
            }
            if (launcher) launcher.updateResults()
        })
    }

    function bwRequest(method, endpoint, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var ok = xhr.status >= 200 && xhr.status < 300
                cb(xhr.responseText, ok)
            }
        }
        xhr.open(method, serverUrl + endpoint)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(body ? JSON.stringify(body) : "")
    }

    function checkStatus() {
        if (!serverRunning) return
        bwRequest("GET", "/status", null, function(resp, success) {
            if (!success) {
                Logger.w("BitwardenProvider", "status request failed:", resp)
                serverRunning = false
                if (launcher) launcher.updateResults()
                return
            }
            try {
                var data = JSON.parse(resp)
                var stat = data.data?.status || data.status
                Logger.i("BitwardenProvider", "vault status:", stat)
                if (stat === "unlocked") {
                    unlocked = true
                    if (!loaded) fetchItems()
                } else {
                    unlocked = false
                }
            } catch (e) {
                Logger.e("BitwardenProvider", "status parse error:", e)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function unlockVault() {
        if (!serverRunning) return
        var password = pluginApi?.pluginSettings?.password || ""
        if (!password) return

        Logger.i("BitwardenProvider", "unlocking vault...")
        bwRequest("POST", "/unlock", { password: password }, function(resp, success) {
            if (!success) {
                Logger.e("BitwardenProvider", "unlock failed:", resp)
                if (launcher) launcher.updateResults()
                return
            }
            try {
                var data = JSON.parse(resp)
                if (data.success || data.data) {
                    unlocked = true
                    Logger.i("BitwardenProvider", "vault unlocked")
                    fetchItems()
                } else {
                    Logger.e("BitwardenProvider", "unlock unsuccessful:", resp)
                }
            } catch (e) {
                Logger.e("BitwardenProvider", "unlock parse error:", e)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function fetchItems() {
        if (fetching || !serverRunning) return
        fetching = true
        bwRequest("GET", "/list/object/items", null, function(resp, success) {
            fetching = false
            if (!success) {
                Logger.e("BitwardenProvider", "fetch failed:", resp)
                if (launcher) launcher.updateResults()
                return
            }
            try {
                var data = JSON.parse(resp)
                items = data.data?.data || []
                loaded = true
                Logger.i("BitwardenProvider", "Loaded", items.length, "items")
            } catch (e) {
                Logger.e("BitwardenProvider", "fetch parse error:", e)
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

        if (!serverRunning) {
            return [
                { "name": "bw serve not running", "description": "Start: bw serve --port 8087", "icon": "alert-circle", "isTablerIcon": true,
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
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + text.replace(/'/g, "'\''") + "' | wl-copy"])
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
