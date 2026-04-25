import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    // ── Injected by Noctalia ─────────────────────────────────────────────
    property var pluginApi: null
    property var launcher: null

    // ── Provider identity ────────────────────────────────────────────────
    property string name: "Bitwarden Vault"
    property string supportedLayouts: "list"
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    // ── Category browsing ────────────────────────────────────────────────
    property bool showsCategories: false
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({ "all": "key" })

    // ── Internal state ─────────────────────────────────────────────────
    property var items: []           // cached vault items
    property bool unlocked: false    // vault is unlocked
    property bool checkingBw: false   // checking if bw is installed
    property string sessionToken: ""

    // ── Helpers ─────────────────────────────────────────────────────────
    readonly property string bwAvailable:
        (pluginApi?.pluginSettings?.bwAvailable || false)

    readonly property string vaultUrl:
        pluginApi?.pluginSettings?.vaultUrl ||
        pluginApi?.manifest?.metadata?.defaultSettings?.vaultUrl || ""

    // ── Lifecycle ─────────────────────────────────────────────────────────

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        checkBwInstalled()
    }

    function onOpened() {
        pendingDeleteId = ""
        maybeRefresh()
    }

    function checkBwInstalled() {
        var proc = Quickshell.execDetached(["which", "bw"])
        proc Completed: {
            if (proc.exitCode === 0) {
                pluginApi.pluginSettings.bwAvailable = true
                Logger.i("BitwardenProvider", "bw CLI found")
                checkUnlockStatus()
            } else {
                pluginApi.pluginSettings.bwAvailable = false
                Logger.w("BitwardenProvider", "bw CLI not found - install from https://bitwarden.com/download")
            }
        }
    }

    function checkUnlockStatus() {
        var proc = Quickshell.execDetached(["bw", "status"])
        proc Completed: {
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

    // ── Command handling ─────────────────────────────────────────────────

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">bw")
    }

    function commands() {
        return [
            {
                "name": ">bitwarden",
                "description": "Search Bitwarden vault (use # for type filter)",
                "icon": "key",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden ") }
            },
            {
                "name": ">bw",
                "description": "Search Bitwarden vault (use # for type filter)",
                "icon": "key",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw ") }
            },
            {
                "name": ">bitwarden username",
                "description": "Copy username for a login",
                "icon": "user",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden username ") }
            },
            {
                "name": ">bw username",
                "description": "Copy username for a login",
                "icon": "user",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw username ") }
            },
            {
                "name": ">bitwarden password",
                "description": "Copy password for a login",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden password ") }
            },
            {
                "name": ">bw password",
                "description": "Copy password for a login",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw password ") }
            },
            {
                "name": ">bitwarden items",
                "description": "Browse all vault items",
                "icon": "list",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden items ") }
            },
            {
                "name": ">bw items",
                "description": "Browse all vault items",
                "icon": "list",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bw items ") }
            },
            {
                "name": ">bitwarden new",
                "description": "Add a new vault item",
                "icon": "plus",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden new") }
            },
            {
                "name": ">bitwarden edit",
                "description": "Edit an existing vault item",
                "icon": "pencil",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden edit ") }
            },
            {
                "name": ">bitwarden delete",
                "description": "Delete a vault item",
                "icon": "trash",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden delete ") }
            },
            {
                "name": ">bitwarden unlock",
                "description": "Unlock your Bitwarden vault",
                "icon": "lock-open",
                "isTablerIcon": true,
                "onActivate": function() {
                    ToastService.showNotice("Run 'bw unlock' in terminal, then reload the plugin")
                    launcher.close()
                }
            }
        ]
    }

    // ── Results ───────────────────────────────────────────────────────────

    function getResults(searchText) {
        // Strip either prefix
        var query = ""
        var mode = "search" // search, username, password, items

        if (searchText.startsWith(">bitwarden")) {
            query = searchText.slice(10).trim()
        } else if (searchText.startsWith(">bw")) {
            query = searchText.slice(3).trim()
        } else {
            return []
        }

        // bw not installed
        if (!pluginApi?.pluginSettings?.bwAvailable) {
            return [{
                "name": "Bitwarden CLI not installed",
                "description": "Install from bitwarden.com/download then unlock your vault",
                "icon": "alert-circle",
                "isTablerIcon": true,
                "onActivate": function() {
                    Quickshell.execDetached(["xdg-open", "https://bitwarden.com/download"])
                }
            }]
        }

        // Check mode
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

        // "new" shortcut
        if (query === "new") {
            openCreatePanel()
            return []
        }

        // "edit" mode - search for item to edit
        if (query.startsWith("edit ")) {
            var editQuery = query.slice(5).toLowerCase()
            var matched = []
            for (var i = 0; i < items.length; i++) {
                var it = items[i]
                var haystack = ((it.name || "") + " " + (it.login?.username || "") + " " + (it.login?.uri || "")).toLowerCase()
                if (fuzzyMatch(editQuery, haystack)) {
                    matched.push(it)
                }
            }
            if (matched.length === 0 && loaded) {
                return [{
                    "name": "No items match",
                    "description": "Try a different search term",
                    "icon": "search-off",
                    "isTablerIcon": true,
                    "onActivate": function() {}
                }]
            }
            var editResults = []
            for (var j = 0; j < Math.min(matched.length, 20); j++) {
                editResults.push(makeEditResult(matched[j]))
            }
            return editResults
        }

        // "delete" mode - search for item to delete
        if (query.startsWith("delete ")) {
            var delQuery = query.slice(7).toLowerCase()
            var delMatched = []
            for (var i = 0; i < items.length; i++) {
                var it = items[i]
                var haystack = ((it.name || "") + " " + (it.login?.username || "") + " " + (it.login?.uri || "")).toLowerCase()
                if (fuzzyMatch(delQuery, haystack)) {
                    delMatched.push(it)
                }
            }
            if (delMatched.length === 0 && loaded) {
                return [{
                    "name": "No items match",
                    "description": "Try a different search term",
                    "icon": "search-off",
                    "isTablerIcon": true,
                    "onActivate": function() {}
                }]
            }
            var delResults = []
            for (var j = 0; j < Math.min(delMatched.length, 20); j++) {
                delResults.push(makeDeleteResult(delMatched[j]))
            }
            return delResults
        }

        // Not unlocked
        if (!unlocked) {
            return [{
                "name": "Vault is locked",
                "description": "Run 'bw unlock' in terminal or configure session token in settings",
                "icon": "lock",
                "isTablerIcon": true,
                "onActivate": function() {
                    ToastService.showNotice("Unlock Bitwarden vault first")
                }
            }]
        }

        // Still loading
        if (fetching) {
            return [{
                "name": "Loading vault…",
                "description": "Fetching items from Bitwarden",
                "icon": "loader",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
        }

        var pool = items

        var results = []
        if (query === "") {
            // Browse mode — show everything
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) {
                results.push(makeResult(pool[i], mode))
            }
        } else if (query.startsWith("#")) {
            // Type filter
            var typeQuery = query.slice(1).toLowerCase()
            for (var i = 0; i < pool.length && results.length < 50; i++) {
                var type = (pool[i].type || "").toLowerCase()
                if (type.indexOf(typeQuery) !== -1) {
                    results.push(makeResult(pool[i], mode))
                }
            }
        } else {
            // Text search
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

    // ── Fuzzy match ─────────────────────────────────────────────────────

    function fuzzyMatch(needle, haystack) {
        if (needle === "") return true
        var ni = 0
        for (var hi = 0; hi < haystack.length && ni < needle.length; hi++) {
            if (haystack[hi] === needle[ni]) ni++
        }
        return ni === needle.length
    }

    // ── Load items from vault ─────────────────────────────────────────

    property bool fetching: false
    property bool loaded: false

    function loadItems() {
        if (fetching || !sessionToken) return
        fetching = true

        var proc = Quickshell.execDetached(["bw", "list", "items", "--sessionid", sessionToken])
        proc Completed: {
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

    // ── Result builder ───────────────────────────────────────────────────

    property string pendingDeleteId: ""

    function makeResult(item, mode) {
        var name = item.name || "Untitled"
        var type = item.type || "login"
        var subtitle = type

        if (mode === "username" && item.login?.username) {
            subtitle = item.login.username
        } else if (mode === "password") {
            subtitle = "Click to copy password"
        } else if (mode === "items") {
            subtitle = (item.login?.username || "") + (item.login?.uri ? " • " + item.login.uri : "")
        } else if (item.login?.username) {
            subtitle = item.login.username
        }

        var iconName = "key"
        if (type === "login") iconName = "user"
        else if (type === "note") iconName = "file-text"
        else if (type === "card") iconName = "credit-card"
        else if (type === "identity") iconName = "id"

        return {
            "name": name,
            "description": subtitle,
            "icon": iconName,
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
                } else if (mode === "items") {
                    openItemPanel(item)
                } else {
                    openItemPanel(item)
                }
            }
        }
    }

    function makeEditResult(item) {
        var name = item.name || "Untitled"
        var subtitle = (item.login?.username || "") + (item.login?.uri ? " • " + item.login.uri : "")

        return {
            "name": name,
            "description": subtitle,
            "icon": "pencil",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                openEditPanel(item)
            }
        }
    }

    function makeDeleteResult(item) {
        var name = item.name || "Untitled"
        var subtitle = (item.login?.username || "") + (item.login?.uri ? " • " + item.login.uri : "")

        return {
            "name": name,
            "description": subtitle,
            "icon": "trash",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                if (pendingDeleteId === String(item.id)) {
                    pendingDeleteId = ""
                    deleteItem(item.id)
                    launcher.close()
                } else {
                    pendingDeleteId = String(item.id)
                    ToastService.showNotice("Press again to confirm delete")
                }
            }
        }
    }

    function deleteItem(id) {
        var sessionToken = getSessionToken()
        if (!sessionToken) {
            ToastService.showNotice("Vault is locked")
            return
        }

        var proc = Quickshell.execDetached([
            "bw", "delete", "item", id, "--sessionid", sessionToken
        ])
        proc.Completed: {
            if (proc.exitCode === 0) {
                ToastService.showNotice("Item deleted")
                loaded = false
                items = []
                loadItems()
            } else {
                Logger.e("BitwardenProvider", "Delete failed:", proc.exitCode)
                ToastService.showNotice("Delete failed")
            }
        }
    }

    function getSessionToken() {
        if (pluginApi?.pluginSettings?.sessionToken) {
            return pluginApi.pluginSettings.sessionToken
        }
        return ""
    }

    // ── Clipboard ────────────────────────────────────────────────────────

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + text.replace(/'/g, "'\\''") + "' | wl-copy"])
    }

    // ── Panel helpers ─────────────────────────────────────────────────────

    function openItemPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "view"
            pluginApi.pluginSettings._viewItem = item
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    function openEditPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "edit"
            pluginApi.pluginSettings._editItem = item
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    function openCreatePanel() {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "create"
            pluginApi.pluginSettings._editItem = null
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }
}