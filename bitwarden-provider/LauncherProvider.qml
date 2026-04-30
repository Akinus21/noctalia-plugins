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
    property string vaultStatus: "unknown"

    property string installState: "unknown"
    property string bwPath: ""

    readonly property string installDir: {
        var home = Quickshell.env("HOME") || "/root"
        return home + "/.local/bin"
    }
    readonly property string installTarget: installDir + "/bw"

    property string updateState: "idle"
    property string installedVersion: ""
    property string latestVersion: ""

    readonly property int updateIntervalMs: 24 * 60 * 60 * 1000

    Timer {
        id: updateCheckTimer
        interval: 60 * 1000
        repeat: false
        onTriggered: maybeCheckForUpdate()
    }

    Timer {
        id: updateCheckRepeatTimer
        interval: root.updateIntervalMs
        repeat: true
        onTriggered: maybeCheckForUpdate()
    }

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        installedVersion = pluginApi?.pluginSettings?.bwVersion || ""
        checkBwInstalled()
    }

    function onOpened() {
        if (installState === "ready" && !unlocked) checkStatus()
    }

    Process {
        id: whichProc
        command: []

        onExited: function(exitCode) {
            var found = String(stdout || "").trim().split("\n")[0].trim()
            if (found.length > 0) {
                root.bwPath = found
                root.installState = "ready"
                Logger.i("BitwardenProvider", "bw found at:", root.bwPath)
                checkStatus()
                updateCheckTimer.restart()
                updateCheckRepeatTimer.start()
            } else {
                root.installState = "missing"
                Logger.w("BitwardenProvider", "bw not found, will download binary")
                downloadBw()
            }
            if (root.launcher) root.launcher.updateResults()
        }
    }

    function checkBwInstalled() {
        if (whichProc.running) return
        installState = "checking"
        whichProc.command = ["sh", "-c",
            "command -v bw 2>/dev/null || " +
            "( [ -x " + shellQuote(root.installTarget) + " ] && echo " + shellQuote(root.installTarget) + " )"
        ]
        whichProc.running = true
        if (launcher) launcher.updateResults()
    }

    Process {
        id: installProc
        command: []

        onExited: function(exitCode) {
            if (exitCode === 0) {
                Logger.i("BitwardenProvider", "bw binary installed to", root.installTarget)
                checkBwInstalled()
            } else {
                root.installState = "failed"
                Logger.e("BitwardenProvider", "bw download failed, exit:", exitCode)
            }
            if (root.launcher) root.launcher.updateResults()
        }
    }

    function downloadBw() {
        if (installProc.running) return
        installState = "installing"
        var script = [
            "set -e",
            "mkdir -p " + shellQuote(installDir),
            "TMPDIR=$(mktemp -d)",
            "trap 'rm -rf \"$TMPDIR\"' EXIT",
            "echo 'Fetching latest release info...'",
            "TAG=$(curl -fsSL 'https://api.github.com/repos/bitwarden/clients/releases' \\",
            "  | grep -o '\"tag_name\": *\"cli/v[^\"]*\"' \\",
            "  | head -1 \\",
            "  | sed 's/.*\"cli\\/\\(v[^\"]*\\)\".*/\\1/')",
            "if [ -z \"$TAG\" ]; then echo 'ERROR: could not determine latest version' >&2; exit 1; fi",
            "echo \"Downloading bw $TAG...\"",
            "URL=\"https://github.com/bitwarden/clients/releases/download/cli%2F${TAG}/bw-linux-${TAG}.zip\"",
            "curl -fsSL --progress-bar -o \"$TMPDIR/bw.zip\" \"$URL\"",
            "unzip -o \"$TMPDIR/bw.zip\" bw -d \"$TMPDIR\"",
            "mv \"$TMPDIR/bw\" " + shellQuote(installTarget),
            "chmod +x " + shellQuote(installTarget),
            "echo 'Done'"
        ].join("\n")
        installProc.command = ["sh", "-c", script]
        installProc.running = true
        if (launcher) launcher.updateResults()
    }

    Process {
        id: versionProc
        command: []

        onExited: function(exitCode) {
            var ver = String(stdout || "").trim()
            if (exitCode === 0 && ver.length > 0) {
                root.installedVersion = ver.startsWith("v") ? ver : "v" + ver
                pluginApi.pluginSettings.bwVersion = root.installedVersion
                pluginApi.saveSettings()
                Logger.i("BitwardenProvider", "Installed bw version:", root.installedVersion)
                fetchLatestVersion()
            } else {
                Logger.w("BitwardenProvider", "Could not read bw version, skipping update check")
                root.updateState = "idle"
            }
        }
    }

    Process {
        id: latestTagProc
        command: []

        onExited: function(exitCode) {
            var tag = String(stdout || "").trim()
            pluginApi.pluginSettings.bwLastUpdateCheck = Math.floor(Date.now() / 1000)
            pluginApi.saveSettings()

            if (exitCode !== 0 || tag.length === 0) {
                Logger.w("BitwardenProvider", "Could not fetch latest bw version tag")
                root.updateState = "idle"
                return
            }

            root.latestVersion = tag
            Logger.i("BitwardenProvider", "Latest bw version:", tag, "- installed:", root.installedVersion)

            if (tag !== root.installedVersion) {
                Logger.i("BitwardenProvider", "Update available:", root.installedVersion, "->", tag)
                updateBw(tag)
            } else {
                Logger.i("BitwardenProvider", "bw is up to date")
                root.updateState = "idle"
            }
        }
    }

    Process {
        id: updateProc
        command: []

        onExited: function(exitCode) {
            if (exitCode === 0) {
                Logger.i("BitwardenProvider", "bw updated to", root.latestVersion)
                root.installedVersion = root.latestVersion
                pluginApi.pluginSettings.bwVersion = root.latestVersion
                pluginApi.saveSettings()
            } else {
                Logger.e("BitwardenProvider", "bw update failed, exit:", exitCode)
            }
            root.updateState = "idle"
        }
    }

    function maybeCheckForUpdate() {
        if (installState !== "ready") return
        if (updateState !== "idle") return
        if (versionProc.running || latestTagProc.running || updateProc.running) return

        var lastCheck = pluginApi?.pluginSettings?.bwLastUpdateCheck || 0
        var age = (Date.now() / 1000) - lastCheck
        if (age < (updateIntervalMs / 1000)) {
            Logger.i("BitwardenProvider", "Update check skipped - checked", Math.round(age / 3600), "h ago")
            return
        }

        Logger.i("BitwardenProvider", "Checking for bw CLI updates...")
        updateState = "checking"
        versionProc.command = [root.bwPath, "--version"]
        versionProc.running = true
    }

    function fetchLatestVersion() {
        latestTagProc.command = ["sh", "-c",
            "curl -fsSL 'https://api.github.com/repos/bitwarden/clients/releases' " +
            "| grep -o '\"tag_name\": *\"cli/v[^\"]*\"' " +
            "| head -1 " +
            "| sed 's/.*\"cli\\/\\(v[^\"]*\\)\".*/\\1/'"
        ]
        latestTagProc.running = true
    }

    function updateBw(tag) {
        if (updateProc.running) return
        updateState = "updating"

        var script = [
            "set -e",
            "TMPDIR=$(mktemp -d)",
            "trap 'rm -rf \"$TMPDIR\"' EXIT",
            "URL=\"https://github.com/bitwarden/clients/releases/download/cli%2F" + tag + "/bw-linux-" + tag + ".zip\"",
            "curl -fsSL -o \"$TMPDIR/bw.zip\" \"$URL\"",
            "unzip -o \"$TMPDIR/bw.zip\" bw -d \"$TMPDIR\"",
            "mv \"$TMPDIR/bw\" " + shellQuote(installTarget),
            "chmod +x " + shellQuote(installTarget),
            "echo 'Done'"
        ].join("\n")

        updateProc.command = ["sh", "-c", script]
        updateProc.running = true
    }

    Process {
        id: statusProc
        command: []

        onExited: function(exitCode) {
            var raw = String(stdout || "").trim()
            try {
                var parsed = JSON.parse(raw)
                root.vaultStatus = parsed.status || "unauthenticated"
                root.unlocked = (root.vaultStatus === "unlocked")
                Logger.i("BitwardenProvider", "Vault status:", root.vaultStatus)
                if (root.unlocked && !root.loaded) fetchItems()
            } catch (e) {
                Logger.w("BitwardenProvider", "Could not parse bw status:", raw)
                root.vaultStatus = "unauthenticated"
                root.unlocked = false
            }
            if (root.launcher) root.launcher.updateResults()
        }
    }

    function checkStatus() {
        if (statusProc.running || installState !== "ready") return
        statusProc.command = sessionToken
            ? [root.bwPath, "status", "--session", sessionToken]
            : [root.bwPath, "status"]
        statusProc.running = true
    }

    Process {
        id: unlockProc
        command: []

        onExited: function(exitCode) {
            var token = String(stdout || "").trim()
            if (exitCode === 0 && token.length > 20) {
                Logger.i("BitwardenProvider", "Unlock successful")
                root.sessionToken = token
                pluginApi.pluginSettings.sessionToken = token
                pluginApi.saveSettings()
                root.unlocked = true
                root.vaultStatus = "unlocked"
                fetchItems()
            } else {
                Logger.e("BitwardenProvider", "Unlock/login failed, exit:", exitCode)
            }
            if (root.launcher) root.launcher.updateResults()
        }
    }

    function unlockVault() {
        if (unlockProc.running || installState !== "ready") return

        var password = pluginApi?.pluginSettings?.password || ""
        var email = pluginApi?.pluginSettings?.email || ""

        if (!password) return

        if (vaultStatus === "unauthenticated") {
            if (!email) return
            unlockProc.command = [
                "sh", "-c",
                "BW_PASSWORD=" + shellQuote(password) + " " +
                shellQuote(root.bwPath) + " login " + shellQuote(email) +
                " --passwordenv BW_PASSWORD --raw 2>&1"
            ]
        } else {
            unlockProc.command = [
                "sh", "-c",
                "BW_PASSWORD=" + shellQuote(password) + " " +
                shellQuote(root.bwPath) + " unlock --passwordenv BW_PASSWORD --raw 2>&1"
            ]
        }

        unlockProc.running = true
        if (launcher) launcher.updateResults()
    }

    Process {
        id: fetchProc
        command: []

        onExited: function(exitCode) {
            root.fetching = false
            var raw = String(stdout || "").trim()

            if (exitCode !== 0 || !raw) {
                Logger.e("BitwardenProvider", "bw list items failed, exit:", exitCode)
                if (exitCode !== 0) {
                    root.unlocked = false
                    root.vaultStatus = "locked"
                }
                if (root.launcher) root.launcher.updateResults()
                return
            }

            try {
                var parsed = JSON.parse(raw)
                root.items = parsed
                root.loaded = true
                Logger.i("BitwardenProvider", "Loaded", parsed.length, "items")
            } catch (e) {
                Logger.e("BitwardenProvider", "Failed to parse items JSON:", e)
            }

            if (root.launcher) root.launcher.updateResults()
        }
    }

    function fetchItems() {
        if (fetching || !sessionToken || installState !== "ready") return
        fetching = true
        fetchProc.command = [root.bwPath, "list", "items", "--session", sessionToken]
        fetchProc.running = true
        if (launcher) launcher.updateResults()
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

        if (installState === "unknown" || installState === "checking") {
            return [{ "name": "Checking for bw CLI...", "description": "Scanning PATH", "icon": "loader", "isTablerIcon": true }]
        }

        if (installState === "missing") {
            return [{ "name": "bw CLI not found", "description": "Preparing download from GitHub...", "icon": "loader", "isTablerIcon": true }]
        }

        if (installState === "installing") {
            return [{ "name": "Installing bw CLI...", "description": "Downloading to ~/.local/bin - please wait", "icon": "loader", "isTablerIcon": true }]
        }

        if (installState === "failed") {
            return [{
                "name": "bw CLI install failed",
                "description": "Click to copy manual install command to clipboard",
                "icon": "alert-circle", "isTablerIcon": true,
                "onActivate": function() {
                    copyToClipboard(
                        "TAG=$(curl -fsSL 'https://api.github.com/repos/bitwarden/clients/releases' " +
                        "| grep -o '\"tag_name\": *\"cli/v[^\"]*\"' | head -1 | sed 's/.*\"cli\\/\\(v[^\"]*\\)\".*/\\1/') && " +
                        "curl -fsSL -o /tmp/bw.zip \"https://github.com/bitwarden/clients/releases/download/cli%2F${TAG}/bw-linux-${TAG}.zip\" && " +
                        "unzip -o /tmp/bw.zip bw -d ~/.local/bin && chmod +x ~/.local/bin/bw"
                    )
                }
            }]
        }

        if (!unlocked) {
            if (unlockProc.running) {
                return [{ "name": "Unlocking vault...", "description": "Please wait", "icon": "loader", "isTablerIcon": true }]
            }

            var hasCreds = !!(pluginApi?.pluginSettings?.password || "")
            if (hasCreds) {
                var label = vaultStatus === "unauthenticated"
                    ? "Not logged in - click to login"
                    : "Vault locked - click to unlock"
                var icon = vaultStatus === "unauthenticated" ? "login" : "lock"
                return [{
                    "name": label,
                    "description": "Uses credentials from settings",
                    "icon": icon, "isTablerIcon": true,
                    "onActivate": function() { unlockVault() }
                }]
            }

            return [{
                "name": "Not configured",
                "description": "Open settings to enter your email and master password",
                "icon": "settings", "isTablerIcon": true,
                "onActivate": function() { openSettings() }
            }]
        }

        if (query.startsWith("username ")) { mode = "username"; query = query.slice(9).trim() }
        else if (query.startsWith("password ")) { mode = "password"; query = query.slice(9).trim() }
        else if (query === "username") { mode = "username"; query = "" }
        else if (query === "password") { mode = "password"; query = "" }

        if (fetching) {
            return [{ "name": "Loading vault...", "description": "Fetching items from bw", "icon": "loader", "isTablerIcon": true }]
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
            return [{ "name": "No items found", "description": "Try a different search term", "icon": "search-off", "isTablerIcon": true }]
        }

        return results
    }

    function makeResult(item, mode) {
        var itemName = item.name || "Untitled"
        var username = item.login ? (item.login.username || "") : ""
        var password = item.login ? (item.login.password || "") : ""
        var uri = item.login && item.login.uris ? (item.login.uris[0]?.uri || "") : ""

        var subtitle = username || uri || "No username"
        if (mode === "password") subtitle = password ? "Click to copy password" : "No password stored"

        return {
            "name": itemName,
            "description": subtitle,
            "icon": "key",
            "isTablerIcon": true,
            "provider": root,
            "onActivate": function() {
                if (mode === "username" && username) {
                    copyToClipboard(username)
                    launcher.close()
                } else if (mode === "password" && password) {
                    copyToClipboard(password)
                    launcher.close()
                } else {
                    openItemPanel(item)
                }
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

    function shellQuote(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'"
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' " + shellQuote(text) + " | wl-copy"])
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