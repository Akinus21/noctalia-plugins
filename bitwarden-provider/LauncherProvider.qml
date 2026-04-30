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
    property string bwBinary: ""

    property string updateState: "idle"
    property string installedVersion: ""
    property string latestVersion: ""
    readonly property int updateIntervalMs: 24 * 60 * 60 * 1000

    property string cacheDir: "/var/home/gabriel/.cache/noctalia"

    FileView { id: outputFile; path: cacheDir + "/bw_out" }

    Timer {
        id: updateCheckTimer
        interval: 60 * 1000; repeat: false
        onTriggered: maybeCheckForUpdate()
    }
    Timer {
        id: updateCheckRepeatTimer
        interval: root.updateIntervalMs; repeat: true
        onTriggered: maybeCheckForUpdate()
    }

    function init() {
        Logger.i("BitwardenProvider", "Initializing")
        sessionToken = pluginApi?.pluginSettings?.sessionToken || ""
        installedVersion = pluginApi?.pluginSettings?.bwVersion || ""
        checkBw()
    }

    function onOpened() {
        if (installState === "ready" && !unlocked) checkStatus()
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function runScript(cmd, cb) {
        var full = "mkdir -p " + cacheDir + " && rm -f " + cacheDir + "/bw_out && " + cmd + " > " + cacheDir + "/bw_out 2>&1"
        pollScript(full, cb)
    }

    function pollScript(full, cb) {
        try {
            Quickshell.execDetached(["sh", "-c", full])
        } catch (e) {
            Logger.e("BitwardenProvider", "execDetached error:", e)
        }
        pollTimer.cmd = full
        pollTimer.cb = cb
        pollTimer.restart()
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: false
        property string cmd: ""
        property var cb: null
        onTriggered: {
            var out = String(outputFile.content || "")
            if (cb) cb(out)
        }
    }

    Timer {
        id: quickPollTimer
        interval: 1500
        repeat: false
        property var cb: null
        onTriggered: {
            var out = String(outputFile.content || "")
            if (cb) cb(out)
        }
    }

    function quickRun(cmd, cb) {
        var full = "mkdir -p " + cacheDir + " && rm -f " + cacheDir + "/bw_out && " + cmd + " > " + cacheDir + "/bw_out 2>&1"
        try {
            Quickshell.execDetached(["sh", "-c", full])
        } catch (e) {
            Logger.e("BitwardenProvider", "execDetached error:", e)
        }
        quickPollTimer.cb = cb
        quickPollTimer.restart()
    }

    function checkBw() {
        installState = "checking"
        runScript(
            "command -v bw 2>/dev/null || " +
            "( [ -x ~/.local/bin/bw ] && echo ~/.local/bin/bw )",
            function(out) {
                var found = out.trim().split("\n")[0].trim()
                if (found.length > 0) {
                    bwBinary = found
                    installState = "ready"
                    Logger.i("BitwardenProvider", "bw found:", bwBinary)
                    checkStatus()
                    updateCheckTimer.restart()
                    updateCheckRepeatTimer.start()
                } else {
                    Logger.w("BitwardenProvider", "bw not found, will download")
                    downloadBw()
                }
                if (launcher) launcher.updateResults()
            }
        )
    }

    function downloadBw() {
        installState = "installing"
        var py = "python3 -c \"\n" +
            "import os, json, urllib.request, zipfile, io, stat\n" +
            "dest = " + JSON.stringify("/var/home/gabriel/.local/bin/bw") + "\n" +
            "os.makedirs(os.path.dirname(dest), exist_ok=True)\n" +
            "print('Finding latest bw version...')\n" +
            "api = 'https://api.github.com/repos/bitwarden/clients/releases?per_page=20'\n" +
            "req = urllib.request.Request(api, headers={'User-Agent': 'noctalia-bw'})\n" +
            "with urllib.request.urlopen(req, timeout=30) as r:\n" +
            "    releases = json.loads(r.read().decode())\n" +
            "tag = None\n" +
            "for rel in releases:\n" +
            "    tn = rel.get('tag_name', '')\n" +
            "    if tn.startswith('cli/v'):\n" +
            "        tag = tn.split('cli/')[1]\n" +
            "        break\n" +
            "if not tag:\n" +
            "    print('ERROR: no cli tag found'); exit(1)\n" +
            "print('Downloading bw ' + tag + '...')\n" +
            "dl = 'https://github.com/bitwarden/clients/releases/download/cli%2F' + tag + '/bw-linux-' + tag + '.zip'\n" +
            "req2 = urllib.request.Request(dl, headers={'User-Agent': 'noctalia-bw'})\n" +
            "with urllib.request.urlopen(req2, timeout=180) as r2:\n" +
            "    zdata = io.BytesIO(r2.read())\n" +
            "with zipfile.ZipFile(zdata) as zf:\n" +
            "    content = zf.read('bw')\n" +
            "with open(dest, 'wb') as f:\n" +
            "    f.write(content)\n" +
            "st = os.stat(dest)\n" +
            "os.chmod(dest, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)\n" +
            "print('OK')\n" +
            "\""
        runScript(py, function(out) {
            Logger.i("BitwardenProvider", "download output:", out)
            if (out.indexOf("OK") >= 0 || out.indexOf("Done") >= 0) {
                Logger.i("BitwardenProvider", "bw installed")
                checkBw()
            } else {
                installState = "failed"
                Logger.e("BitwardenProvider", "bw download failed:", out)
                if (launcher) launcher.updateResults()
            }
        })
        if (launcher) launcher.updateResults()
    }

    function checkStatus() {
        if (installState !== "ready") return
        var cmd = shellQuote(bwBinary) + " status"
        if (sessionToken) cmd += " --session " + sessionToken
        quickRun(cmd, function(out) {
            Logger.i("BitwardenProvider", "status out:", out.trim())
            try {
                var s = JSON.parse(out.trim()).status
                vaultStatus = s
                unlocked = (s === "unlocked")
                Logger.i("BitwardenProvider", "vault:", vaultStatus)
                if (unlocked && !loaded) fetchItems()
            } catch (e) {
                vaultStatus = "unauthenticated"
                unlocked = false
                Logger.w("BitwardenProvider", "status parse error, raw:", out.trim())
            }
            if (launcher) launcher.updateResults()
        })
    }

    function unlockVault() {
        if (installState !== "ready") return
        var password = pluginApi?.pluginSettings?.password || ""
        var email = pluginApi?.pluginSettings?.email || ""
        if (!password) return

        Logger.i("BitwardenProvider", "unlocking, status:", vaultStatus)
        var cmd
        if (vaultStatus === "unauthenticated") {
            if (!email) return
            cmd = "BW_PASSWORD=" + shellQuote(password) + " " + shellQuote(bwBinary) + " login " + shellQuote(email) + " --passwordenv BW_PASSWORD --raw"
        } else {
            cmd = "BW_PASSWORD=" + shellQuote(password) + " " + shellQuote(bwBinary) + " unlock --passwordenv BW_PASSWORD --raw"
        }
        quickRun(cmd, function(out) {
            var token = out.trim()
            Logger.i("BitwardenProvider", "unlock token len:", token.length)
            if (token.length > 20) {
                sessionToken = token
                pluginApi.pluginSettings.sessionToken = token
                pluginApi.saveSettings()
                unlocked = true
                vaultStatus = "unlocked"
                fetchItems()
            } else {
                Logger.e("BitwardenProvider", "unlock failed, output:", token)
            }
            if (launcher) launcher.updateResults()
        })
    }

    function fetchItems() {
        if (fetching || !sessionToken || installState !== "ready") return
        fetching = true
        quickRun(
            shellQuote(bwBinary) + " list items --session " + sessionToken,
            function(out) {
                fetching = false
                if (!out) {
                    unlocked = false
                    vaultStatus = "locked"
                    if (launcher) launcher.updateResults()
                    return
                }
                try {
                    items = JSON.parse(out.trim())
                    loaded = true
                    Logger.i("BitwardenProvider", "Loaded", items.length, "items")
                } catch (e) {
                    unlocked = false
                    vaultStatus = "locked"
                    Logger.e("BitwardenProvider", "Parse error:", e)
                }
                if (launcher) launcher.updateResults()
            }
        )
        if (launcher) launcher.updateResults()
    }

    function maybeCheckForUpdate() {
        if (installState !== "ready") return
        if (updateState !== "idle") return

        var lastCheck = pluginApi?.pluginSettings?.bwLastUpdateCheck || 0
        var age = (Date.now() / 1000) - lastCheck
        if (age < (updateIntervalMs / 1000)) {
            Logger.i("BitwardenProvider", "Update skip, checked", Math.round(age/3600), "h ago")
            return
        }

        updateState = "checking"
        runScript(
            shellQuote(bwBinary) + " --version",
            function(ver) {
                ver = ver.trim()
                if (!ver) { updateState = "idle"; return }
                installedVersion = ver.startsWith("v") ? ver : "v" + ver
                pluginApi.pluginSettings.bwVersion = installedVersion
                pluginApi.saveSettings()

                runScript(
                    "curl -fsSL 'https://api.github.com/repos/bitwarden/clients/releases?per_page=5' " +
                    "| grep -o '\"tag_name\": *\"cli/v[^\"]*\"' | head -1 " +
                    "| sed 's/.*\\\\\"cli\\\\/\\\\(v[^\\\\\"]*\\\\)\\\\\".*/\\\\1/'",
                    function(tag) {
                        tag = tag.trim()
                        pluginApi.pluginSettings.bwLastUpdateCheck = Math.floor(Date.now()/1000)
                        pluginApi.saveSettings()
                        if (tag && tag !== installedVersion) {
                            Logger.i("BitwardenProvider", "Update:", installedVersion, "->", tag)
                            doUpdate(tag)
                        } else {
                            Logger.i("BitwardenProvider", "bw up to date")
                            updateState = "idle"
                        }
                    }
                )
            }
        )
    }

    function doUpdate(tag) {
        updateState = "updating"
        var py = "python3 -c \"\n" +
            "import os, urllib.request, zipfile, io\n" +
            "dest = " + JSON.stringify("/var/home/gabriel/.local/bin/bw") + "\n" +
            "print('Updating bw to " + tag + "...')\n" +
            "dl = 'https://github.com/bitwarden/clients/releases/download/cli%2F" + tag + "/bw-linux-" + tag + ".zip'\n" +
            "req = urllib.request.Request(dl, headers={'User-Agent': 'noctalia-bw'})\n" +
            "with urllib.request.urlopen(req, timeout=180) as r:\n" +
            "    zdata = io.BytesIO(r.read())\n" +
            "with zipfile.ZipFile(zdata) as zf:\n" +
            "    content = zf.read('bw')\n" +
            "with open(dest, 'wb') as f:\n" +
            "    f.write(content)\n" +
            "os.chmod(dest, 0o755)\n" +
            "print('OK')\n" +
            "\""
        runScript(py, function(out) {
            Logger.i("BitwardenProvider", "update output:", out)
            updateState = "idle"
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

        if (installState === "unknown" || installState === "checking") {
            return [{ "name": "Checking for bw CLI...", "description": "Scanning PATH", "icon": "loader", "isTablerIcon": true }]
        }
        if (installState === "missing") {
            return [{ "name": "bw CLI not found", "description": "Downloading from GitHub...", "icon": "loader", "isTablerIcon": true }]
        }
        if (installState === "installing") {
            return [{ "name": "Installing bw CLI...", "description": "Please wait", "icon": "loader", "isTablerIcon": true }]
        }
        if (installState === "failed") {
            return [{ "name": "bw install failed", "description": "Click to copy manual install command", "icon": "alert-circle", "isTablerIcon": true,
                "onActivate": function() { copyToClipboard("pip install --user bitwarden-cli || echo 'Install from https://bitwarden.com/download/'") }
            }]
        }

        if (!unlocked) {
            var hasCreds = !!(pluginApi?.pluginSettings?.password || "")
            if (hasCreds) {
                var label = vaultStatus === "unauthenticated" ? "Not logged in - click to login" : "Vault locked - click to unlock"
                var icon = vaultStatus === "unauthenticated" ? "login" : "lock"
                return [{ "name": label, "description": "Uses credentials from settings", "icon": icon, "isTablerIcon": true, "onActivate": function() { unlockVault() } }]
            }
            return [{ "name": "Not configured", "description": "Enter email and password in settings", "icon": "settings", "isTablerIcon": true, "onActivate": function() { openSettings() } }]
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
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + shellQuote(text) + " | wl-copy"])
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