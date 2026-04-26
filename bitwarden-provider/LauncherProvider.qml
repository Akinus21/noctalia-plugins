import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Bump 2
Item {
    id: root

    // ── Injected by Noctalia ─────────────────────────────────────────────
    property var pluginApi: null
    property var launcher: null

    // ── Provider identity ────────────────────────────────────────────────
    property string name: "Bitwarden Bookmarks"
    property string supportedLayouts: "list"
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    // ── Category browsing ────────────────────────────────────────────────
    property bool showsCategories: false
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({ "all": "items" })

    // ── Internal state ───────────────────────────────────────────────────
    property var items: []           // full cached list
    property bool loaded: false          // cache loaded from disk
    property bool fetching: false        // network request in flight
    property string pendingDeleteId: ""  // item id awaiting confirmation

    // ── Helpers ──────────────────────────────────────────────────────────
    readonly property string cacheFilePath:
        (pluginApi?.pluginDir || "") + "/cache.json"

    readonly property string bitwardenUrl:
        pluginApi?.pluginSettings?.bitwardenUrl ||
        pluginApi?.manifest?.metadata?.defaultSettings?.bitwardenUrl || ""

    readonly property string apiToken:
        pluginApi?.pluginSettings?.apiToken ||
        pluginApi?.manifest?.metadata?.defaultSettings?.apiToken || ""

    readonly property int maxAgeSeconds: {
        var h = pluginApi?.pluginSettings?.cacheMaxAgeHours   ?? 1
        var m = pluginApi?.pluginSettings?.cacheMaxAgeMinutes ?? 0
        var s = pluginApi?.pluginSettings?.cacheMaxAgeSeconds ?? 0
        return h * 3600 + m * 60 + s
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        loadCache()
    }

    function onOpened() {
        showsCategories = true
        selectedCategory = "all"
        pendingDeleteId = ""
        maybeRefresh()
    }

    // ── Command handling ──────────────────────────────────────────────────

    function handleCommand(searchText) {
        return searchText.startsWith(">bitwarden") || searchText.startsWith(">items")
    }

    function commands() {
        return [
            {
                "name": ">bitwarden",
                "description": "Search Bitwarden items (use # for tag search)",
                "icon": "items",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden ") }
            },
            {
                "name": ">items",
                "description": "Search Bitwarden items (use # for tag search)",
                "icon": "items",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">items ") }
            },
            {
                "name": ">bitwarden new",
                "description": "Add a new item",
                "icon": "item-plus",
                "isTablerIcon": true,
                "onActivate": function() { openCreatePanel() }
            },
            {
                "name": ">bitwarden edit",
                "description": "Edit a item",
                "icon": "pencil",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden edit ") }
            },
            {
                "name": ">bitwarden delete",
                "description": "Delete a item",
                "icon": "trash",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bitwarden delete ") }
            }
        ]
    }

    // ── Results ───────────────────────────────────────────────────────────

    function getResults(searchText) {
        // Strip either prefix
        var query = ""
        if (searchText.startsWith(">bitwarden")) {
            query = searchText.slice(9).trim()
        } else if (searchText.startsWith(">items")) {
            query = searchText.slice(10).trim()
        } else {
            return []
        }

        // Not configured yet
        if (!bitwardenUrl || !apiToken) {
            return [{
                "name": "Bitwarden not configured",
                "description": "Open Settings to enter your Bitwarden URL and API token",
                "icon": "settings",
                "isTablerIcon": true,
                "onActivate": function() {
                    if (pluginApi) {
                        pluginApi.withCurrentScreen(function(screen) {
                            BarService.openPluginSettings(screen, pluginApi.manifest)
                        })
                    }
                }
            }]
        }

        // Still loading first-ever cache
        if (!loaded && fetching) {
            return [{
                "name": "Loading items…",
                "description": "Fetching from Bitwarden for the first time",
                "icon": "loader",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
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
                var b = items[i]
                var haystack = ((b.title || "") + " " + (b.url || "")).toLowerCase()
                if (fuzzyMatch(editQuery, haystack)) {
                    matched.push(b)
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
                var b = items[i]
                var haystack = ((b.title || "") + " " + (b.url || "")).toLowerCase()
                if (fuzzyMatch(delQuery, haystack)) {
                    delMatched.push(b)
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

        var pool = items

        // Filter by selected category tag (browse mode)
        if (selectedCategory !== "all") {
            pool = pool.filter(function(b) {
                return (b.tag_names || []).indexOf(selectedCategory) !== -1
            })
        }

        var results = []

        if (query === "") {
            // Browse mode — show everything (up to 100)
            var limit = Math.min(pool.length, 100)
            for (var i = 0; i < limit; i++) {
                results.push(makeResult(pool[i]))
            }
        } else if (query.startsWith("#")) {
            // Tag search
            var tagQuery = query.slice(1).toLowerCase()
            for (var i = 0; i < pool.length && results.length < 50; i++) {
                var tags = (pool[i].tag_names || []).join(" ").toLowerCase()
                if (fuzzyMatch(tagQuery, tags)) {
                    results.push(makeResult(pool[i]))
                }
            }
        } else {
            // Title / URL text search
            var textQuery = query.toLowerCase()
            for (var i = 0; i < pool.length && results.length < 50; i++) {
                var b = pool[i]
                var haystack = ((b.title || "") + " " + (b.url || "") + " " + (b.description || "")).toLowerCase()
                if (fuzzyMatch(textQuery, haystack)) {
                    results.push(makeResult(b))
                }
            }
        }

        if (results.length === 0 && loaded) {
            return [{
                "name": "No items found",
                "description": query.startsWith("#")
                    ? "No tags match \"" + query.slice(1) + "\""
                    : "No items match \"" + query + "\"",
                "icon": "search-off",
                "isTablerIcon": true,
                "onActivate": function() {}
            }]
        }

        return results
    }

    // ── Category helpers ──────────────────────────────────────────────────

    function selectCategory(category) {
        selectedCategory = category
        if (launcher) launcher.updateResults()
    }

    function getCategoryName(category) {
        return category === "all" ? "All" : category
    }

    // ── Result builder ────────────────────────────────────────────────────

    function makeResult(b) {
        var bId      = b.id
        var bUrl     = b.url     || ""
        var bTitle   = b.title   || bUrl
        var bTags    = (b.tag_names || []).join(", ")
        var bDesc    = b.description || ""
        var subtitle = bTags ? bTags : (bDesc ? bDesc : bUrl)

        // Pending delete confirmation state
        var isConfirming = (pendingDeleteId === String(bId))

        return {
            "name": bTitle,
            "description": isConfirming ? "⚠ Press Delete again to confirm removal" : subtitle,
            "icon": "item",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                pendingDeleteId = ""
                Quickshell.execDetached(["xdg-open", bUrl])
                launcher.close()
            },

            "actions": [
                {
                    "name": "Edit",
                    "icon": "pencil",
                    "isTablerIcon": true,
                    "onActivate": function() {
                        pendingDeleteId = ""
                        openEditPanel(b)
                    }
                },
                {
                    "name": isConfirming ? "Confirm Delete" : "Delete",
                    "icon": isConfirming ? "trash-x" : "trash",
                    "isTablerIcon": true,
                    "onActivate": function() {
                        if (pendingDeleteId === String(bId)) {
                            pendingDeleteId = ""
                            deleteBookmark(bId)
                        } else {
                            pendingDeleteId = String(bId)
                            if (launcher) launcher.updateResults()
                        }
                    }
                }
            ]
        }
    }

    function makeEditResult(b) {
        var bUrl   = b.url     || ""
        var bTitle = b.title   || bUrl
        var bTags  = (b.tag_names || []).join(", ")

        return {
            "name": bTitle,
            "description": bTags || bUrl,
            "icon": "pencil",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                openEditPanel(b)
            }
        }
    }

    function makeDeleteResult(b) {
        var bId    = b.id
        var bUrl   = b.url     || ""
        var bTitle = b.title   || bUrl
        var bTags  = (b.tag_names || []).join(", ")

        return {
            "name": bTitle,
            "description": bTags || bUrl,
            "icon": "trash",
            "isTablerIcon": true,
            "provider": root,

            "onActivate": function() {
                if (pendingDeleteId === String(bId)) {
                    pendingDeleteId = ""
                    deleteBookmark(bId)
                    launcher.close()
                } else {
                    pendingDeleteId = String(bId)
                    ToastService.showNotice("Press again to confirm delete")
                    if (launcher) launcher.updateResults()
                }
            }
        }
    }

    // ── Fuzzy match ───────────────────────────────────────────────────────

    function fuzzyMatch(needle, haystack) {
        if (needle === "") return true
        var ni = 0
        for (var hi = 0; hi < haystack.length && ni < needle.length; hi++) {
            if (haystack[hi] === needle[ni]) ni++
        }
        return ni === needle.length
    }

    // ── Cache: load from disk ─────────────────────────────────────────────

    FileView {
        id: cacheFile
        path: root.cacheFilePath
        watchChanges: false

        onLoaded: {
            try {
                var data = JSON.parse(text())
                root.items = data.items || []
                root.loaded    = true
                rebuildCategories()
                if (root.launcher) root.launcher.updateResults()
                Logger.i("BitwardenProvider", "Cache loaded:", root.items.length, "items")
            } catch (e) {
                Logger.w("BitwardenProvider", "Cache parse failed:", e)
                root.loaded = true   // don't block UI even if cache is corrupt
            }
        }

        onLoadFailed: {
            Logger.i("BitwardenProvider", "No cache file yet, will fetch from API")
            root.loaded = true
            fetchBookmarks()
        }
    }

    function loadCache() {
        if (!root.cacheFilePath) return
        cacheFile.path = root.cacheFilePath
    }

    // ── Cache: staleness check & conditional refresh ───────────────────────

    function maybeRefresh() {
        if (!bitwardenUrl || !apiToken) return
        if (fetching) return

        // Read the cached timestamp to decide if a refresh is needed
        try {
            var raw  = cacheFile.text ? cacheFile.text() : ""
            var data = raw ? JSON.parse(raw) : {}
            var ts   = data.fetchedAt || 0
            var age  = (Date.now() / 1000) - ts
            if (age > root.maxAgeSeconds) {
                Logger.i("BitwardenProvider", "Cache stale (" + Math.round(age) + "s), refreshing")
                fetchBookmarks()
            } else {
                Logger.i("BitwardenProvider", "Cache fresh (" + Math.round(age) + "s), skipping fetch")
            }
        } catch (e) {
            fetchBookmarks()
        }
    }

    // ── API: fetch all items ──────────────────────────────────────────

    property var fetchXhr: null

    function fetchBookmarks() {
        if (fetching || !bitwardenUrl || !apiToken) return
        fetching = true
        Logger.i("BitwardenProvider", "Fetching items from", bitwardenUrl)

        var allBookmarks = []

        function fetchPage(url) {
            var xhr = new XMLHttpRequest()
            root.fetchXhr = xhr
            xhr.open("GET", url, true)
            xhr.setRequestHeader("Authorization", "Token " + apiToken)
            xhr.setRequestHeader("Content-Type", "application/json")

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return

                if (xhr.status === 200) {
                    try {
                        var page = JSON.parse(xhr.responseText)
                        allBookmarks = allBookmarks.concat(page.results || [])

                        if (page.next) {
                            fetchPage(page.next)
                        } else {
                            // All pages fetched
                            root.fetching   = false
                            root.items  = allBookmarks
                            root.loaded     = true
                            rebuildCategories()
                            saveCache(allBookmarks)
                            if (root.launcher) root.launcher.updateResults()
                            Logger.i("BitwardenProvider", "Fetched", allBookmarks.length, "items")
                        }
                    } catch (e) {
                        root.fetching = false
                        Logger.e("BitwardenProvider", "Parse error:", e)
                    }
                } else if (xhr.status === 0) {
                    // Network unreachable — stay silent, use cache
                    root.fetching = false
                    Logger.w("BitwardenProvider", "Offline, using cached data")
                } else {
                    root.fetching = false
                    Logger.e("BitwardenProvider", "API error:", xhr.status)
                    ToastService.showError("Bitwarden: API error " + xhr.status)
                }
            }

            xhr.send()
        }

        fetchPage(bitwardenUrl.replace(/\/$/, "") + "/api/items/?limit=100")
    }

    // ── API: delete item ──────────────────────────────────────────────

    function deleteBookmark(id) {
        var xhr = new XMLHttpRequest()
        xhr.open("DELETE", bitwardenUrl.replace(/\/$/, "") + "/api/items/" + id + "/", true)
        xhr.setRequestHeader("Authorization", "Token " + apiToken)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 204) {
                root.items = root.items.filter(function(b) {
                    return String(b.id) !== String(id)
                })
                rebuildCategories()
                saveCache(root.items)
                if (root.launcher) root.launcher.updateResults()
                ToastService.showNotice("Bookmark deleted")
                Logger.i("BitwardenProvider", "Deleted item", id)
            } else {
                Logger.e("BitwardenProvider", "Delete failed:", xhr.status)
                ToastService.showError("Bitwarden: delete failed (" + xhr.status + ")")
            }
        }

        xhr.send()
    }

    // ── Cache: write to disk ──────────────────────────────────────────────

    FileView {
        id: cacheWriter
        path: root.cacheFilePath
        watchChanges: false
    }

    function saveCache(bms) {
        var payload = JSON.stringify({
            fetchedAt: Math.floor(Date.now() / 1000),
            items: bms
        })
        cacheWriter.setText(payload)
        Logger.i("BitwardenProvider", "Cache saved")
    }

    // ── Category rebuild ──────────────────────────────────────────────────

    function rebuildCategories() {
        var tagSet = {}
        for (var i = 0; i < items.length; i++) {
            var tags = items[i].tag_names || []
            for (var j = 0; j < tags.length; j++) {
                tagSet[tags[j]] = true
            }
        }
        var tagList = Object.keys(tagSet).sort()
        var cats    = ["all"].concat(tagList)
        var icons   = { "all": "items" }
        for (var k = 0; k < tagList.length; k++) {
            icons[tagList[k]] = "tag"
        }
        root.categories     = cats
        root.categoryIcons  = icons
        root.showsCategories = cats.length > 1
    }

    // ── Panel helpers ─────────────────────────────────────────────────────

    function openCreatePanel() {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "create"
            pluginApi.pluginSettings._editBookmark = null
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    function openEditPanel(item) {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.pluginSettings._panelMode = "edit"
            pluginApi.pluginSettings._editBookmark = item
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    // ── Panel result callback (called by Panel.qml on save) ───────────────

    function onBookmarkSaved(item) {
        // Update local cache optimistically
        var found = false
        for (var i = 0; i < root.items.length; i++) {
            if (String(root.items[i].id) === String(item.id)) {
                root.items[i] = item
                found = true
                break
            }
        }
        if (!found) root.items.unshift(item)
        rebuildCategories()
        saveCache(root.items)
    }
}