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
    property string name: "Linkding Bookmarks"
    property string supportedLayouts: "list"
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    // ── Category browsing ────────────────────────────────────────────────
    property bool showsCategories: false
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({ "all": "bookmarks" })

    // ── LauncherProvider entry point ───────────────────────────────────────
    Item {
        id: mainInstance
        property var pluginApi: null
    }
    readonly property var mainInstance: mainInstance

    // ── Internal state ───────────────────────────────────────────────────
    property var bookmarks: []           // full cached list
    property bool loaded: false          // cache loaded from disk
    property bool fetching: false        // network request in flight
    property string pendingDeleteId: ""  // bookmark id awaiting confirmation

    // ── Bookmark window instance ───────────────────────────────────────
    property var bookmarkWindow: null

    // ── Helpers ──────────────────────────────────────────────────────────
    readonly property string cacheFilePath:
        (pluginApi?.pluginDir || "") + "/cache.json"

    readonly property string linkdingUrl:
        pluginApi?.pluginSettings?.linkdingUrl ||
        pluginApi?.manifest?.metadata?.defaultSettings?.linkdingUrl || ""

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
        Logger.i("LinkdingProvider", "Initializing")
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
        return searchText.startsWith(">linkding") || searchText.startsWith(">bookmarks")
    }

    function commands() {
        return [
            {
                "name": ">linkding",
                "description": "Search Linkding bookmarks (use # for tag search)",
                "icon": "bookmarks",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">linkding ") }
            },
            {
                "name": ">bookmarks",
                "description": "Search Linkding bookmarks (use # for tag search)",
                "icon": "bookmarks",
                "isTablerIcon": true,
                "onActivate": function() { launcher.setSearchText(">bookmarks ") }
            },
            {
                "name": ">linkding new",
                "description": "Add a new bookmark",
                "icon": "bookmark-plus",
                "isTablerIcon": true,
                "onActivate": function() { openCreatePanel() }
            }
        ]
    }

    // ── Results ───────────────────────────────────────────────────────────

    function getResults(searchText) {
        // Strip either prefix
        var query = ""
        if (searchText.startsWith(">linkding")) {
            query = searchText.slice(9).trim()
        } else if (searchText.startsWith(">bookmarks")) {
            query = searchText.slice(10).trim()
        } else {
            return []
        }

        // Not configured yet
        if (!linkdingUrl || !apiToken) {
            return [{
                "name": "Linkding not configured",
                "description": "Open Settings to enter your Linkding URL and API token",
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
                "name": "Loading bookmarks…",
                "description": "Fetching from Linkding for the first time",
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

        var pool = bookmarks

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
                "name": "No bookmarks found",
                "description": query.startsWith("#")
                    ? "No tags match \"" + query.slice(1) + "\""
                    : "No bookmarks match \"" + query + "\"",
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
            "icon": "bookmark",
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
                root.bookmarks = data.bookmarks || []
                root.loaded    = true
                rebuildCategories()
                if (root.launcher) root.launcher.updateResults()
                Logger.i("LinkdingProvider", "Cache loaded:", root.bookmarks.length, "bookmarks")
            } catch (e) {
                Logger.w("LinkdingProvider", "Cache parse failed:", e)
                root.loaded = true   // don't block UI even if cache is corrupt
            }
        }

        onLoadFailed: {
            Logger.i("LinkdingProvider", "No cache file yet, will fetch from API")
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
        if (!linkdingUrl || !apiToken) return
        if (fetching) return

        // Read the cached timestamp to decide if a refresh is needed
        try {
            var raw  = cacheFile.text ? cacheFile.text() : ""
            var data = raw ? JSON.parse(raw) : {}
            var ts   = data.fetchedAt || 0
            var age  = (Date.now() / 1000) - ts
            if (age > root.maxAgeSeconds) {
                Logger.i("LinkdingProvider", "Cache stale (" + Math.round(age) + "s), refreshing")
                fetchBookmarks()
            } else {
                Logger.i("LinkdingProvider", "Cache fresh (" + Math.round(age) + "s), skipping fetch")
            }
        } catch (e) {
            fetchBookmarks()
        }
    }

    // ── API: fetch all bookmarks ──────────────────────────────────────────

    property var fetchXhr: null

    function fetchBookmarks() {
        if (fetching || !linkdingUrl || !apiToken) return
        fetching = true
        Logger.i("LinkdingProvider", "Fetching bookmarks from", linkdingUrl)

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
                            root.bookmarks  = allBookmarks
                            root.loaded     = true
                            rebuildCategories()
                            saveCache(allBookmarks)
                            if (root.launcher) root.launcher.updateResults()
                            Logger.i("LinkdingProvider", "Fetched", allBookmarks.length, "bookmarks")
                        }
                    } catch (e) {
                        root.fetching = false
                        Logger.e("LinkdingProvider", "Parse error:", e)
                    }
                } else if (xhr.status === 0) {
                    // Network unreachable — stay silent, use cache
                    root.fetching = false
                    Logger.w("LinkdingProvider", "Offline, using cached data")
                } else {
                    root.fetching = false
                    Logger.e("LinkdingProvider", "API error:", xhr.status)
                    ToastService.showError("Linkding: API error " + xhr.status)
                }
            }

            xhr.send()
        }

        fetchPage(linkdingUrl.replace(/\/$/, "") + "/api/bookmarks/?limit=100")
    }

    // ── API: delete bookmark ──────────────────────────────────────────────

    function deleteBookmark(id) {
        var xhr = new XMLHttpRequest()
        xhr.open("DELETE", linkdingUrl.replace(/\/$/, "") + "/api/bookmarks/" + id + "/", true)
        xhr.setRequestHeader("Authorization", "Token " + apiToken)

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 204) {
                root.bookmarks = root.bookmarks.filter(function(b) {
                    return String(b.id) !== String(id)
                })
                rebuildCategories()
                saveCache(root.bookmarks)
                if (root.launcher) root.launcher.updateResults()
                ToastService.showNotice("Bookmark deleted")
                Logger.i("LinkdingProvider", "Deleted bookmark", id)
            } else {
                Logger.e("LinkdingProvider", "Delete failed:", xhr.status)
                ToastService.showError("Linkding: delete failed (" + xhr.status + ")")
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
            bookmarks: bms
        })
        cacheWriter.setText(payload)
        Logger.i("LinkdingProvider", "Cache saved")
    }

    // ── Category rebuild ──────────────────────────────────────────────────

    function rebuildCategories() {
        var tagSet = {}
        for (var i = 0; i < bookmarks.length; i++) {
            var tags = bookmarks[i].tag_names || []
            for (var j = 0; j < tags.length; j++) {
                tagSet[tags[j]] = true
            }
        }
        var tagList = Object.keys(tagSet).sort()
        var cats    = ["all"].concat(tagList)
        var icons   = { "all": "bookmarks" }
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
        openBookmarkWindow("create", null)
        launcher.close()
    }

    function openEditPanel(bookmark) {
        if (!pluginApi) return
        openBookmarkWindow("edit", bookmark)
        launcher.close()
    }

    function openBookmarkWindow(mode, bookmark) {
        if (!pluginApi) return
        if (bookmarkWindow && typeof bookmarkWindow.close === "function") {
            bookmarkWindow.close()
        }
        
        if (!bookmarkWindow) {
            var component = Qt.createComponent(pluginApi.pluginDir + "/BookmarkWindow.qml")
            if (component.status === Component.Error) {
                Logger.e("LinkdingProvider", "Failed to create BookmarkWindow:", component.errorString())
                return
            }
            bookmarkWindow = component.createObject(pluginApi.mainInstance, {
                "pluginApi": pluginApi,
                "mode": mode,
                "bookmark": bookmark
            })
        } else {
            bookmarkWindow.mode = mode
            bookmarkWindow.bookmark = bookmark
            bookmarkWindow.formUrl = mode === "edit" && bookmark ? bookmark.url : ""
            bookmarkWindow.formTags = mode === "edit" && bookmark ? (bookmark.tag_names || []).join(", ") : ""
        }
        
        bookmarkWindow.show()
        Logger.i("LinkdingProvider", "Bookmark window opened, mode:", mode)
    }

    function openEditPanel(bookmark) {
        if (!pluginApi) return
        openBookmarkWindow("edit", bookmark)
        launcher.close()
    }

    // ── Panel result callback (called by Panel.qml on save) ───────────────

    function onBookmarkSaved(bookmark) {
        // Update local cache optimistically
        var found = false
        for (var i = 0; i < root.bookmarks.length; i++) {
            if (String(root.bookmarks[i].id) === String(bookmark.id)) {
                root.bookmarks[i] = bookmark
                found = true
                break
            }
        }
        if (!found) root.bookmarks.unshift(bookmark)
        rebuildCategories()
        saveCache(root.bookmarks)
    }

    Component.onDestruction: {
        if (bookmarkWindow) {
            bookmarkWindow.close()
            bookmarkWindow = null
        }
    }

    Component.onCompleted: {
        init()
    }
}