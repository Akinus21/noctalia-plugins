import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var launcher: null

  property string name: "Flatpak Manager"
  property string supportedLayouts: "list"
  property bool handleSearch: false
  property bool supportsAutoPaste: false

  property bool showsCategories: false
  property string selectedCategory: "all"
  property var categories: ["all"]
  property var categoryIcons: ({ "all": "package" })

  property var installedFlatpaks: []
  property bool loaded: false
  property bool fetching: false

  property string flatpakBuffer: ""

  Process {
    id: listProcess

    stdout: SplitParser {
      onRead: function(data) { root.flatpakBuffer += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakLauncher", "stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      fetching = false
      parseFlatpaks(flatpakBuffer)
      flatpakBuffer = ""
    }
  }

  function init() {
    Logger.i("FlatpakLauncher", "Initializing")
    refreshInstalled()
  }

  function onOpened() {
    refreshInstalled()
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">fp") || searchText.startsWith(">flatpak")
  }

  function commands() {
    return [
      {
        "name": ">fp",
        "description": pluginApi?.tr("launcher.searchPlaceholder") || "Search and manage flatpaks",
        "icon": "package",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp ") }
      },
      {
        "name": ">fp list",
        "description": pluginApi?.tr("commands.list") || "List installed flatpaks",
        "icon": "list",
        "isTablerIcon": true,
        "onActivate": function() { openPanel() }
      },
      {
        "name": ">fp install",
        "description": pluginApi?.tr("commands.install") || "Install a flatpak",
        "icon": "download",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp install ") }
      },
      {
        "name": ">fp update",
        "description": pluginApi?.tr("commands.update") || "Update a flatpak",
        "icon": "refresh",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp update ") }
      },
      {
        "name": ">fp run",
        "description": pluginApi?.tr("commands.run") || "Run a flatpak",
        "icon": "player-play",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp run ") }
      },
      {
        "name": ">fp kill",
        "description": pluginApi?.tr("commands.kill") || "Stop a running flatpak",
        "icon": "player-stop",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp kill ") }
      },
      {
        "name": ">flatpak",
        "description": pluginApi?.tr("launcher.searchPlaceholder") || "Search and manage flatpaks",
        "icon": "package",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">fp ") }
      },
      {
        "name": ">flatpak list",
        "description": pluginApi?.tr("commands.list") || "List installed flatpaks",
        "icon": "list",
        "isTablerIcon": true,
        "onActivate": function() { openPanel() }
      }
    ]
  }

  function getPrefix(query) {
    if (query.startsWith(">flatpak")) return ">flatpak"
    if (query.startsWith(">fp")) return ">fp"
    return null
  }

  function refreshInstalled() {
    if (fetching) return
    fetching = true
    flatpakBuffer = ""
    var scope = getScopeFlag()
    listProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " list --app --columns=name,id,version,origin 2>&1"
    ]
    listProcess.running = true
  }

  function getScopeFlag() {
    var scope = pluginApi?.pluginSettings?.defaultScope || "user"
    return scope === "system" ? "--system" : "--user"
  }

  function parseFlatpaks(raw) {
    if (!raw || raw.trim().length === 0) {
      loaded = true
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("ID") !== -1) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.id) result.push(flatpak)
    }
    root.installedFlatpaks = result
    root.loaded = true
    if (launcher) launcher.updateResults()
    if (result.length === 0) {
      Logger.w("FlatpakLauncher", "No flatpaks parsed from text output, raw sample:", raw.substring(0, 200))
    }
  }

  function parseFlatpakLine(line) {
    var parts = line.split(/\t+/)
    if (parts.length < 2) {
      parts = line.split(/\s{2,}/)
    }
    if (parts.length < 2) {
      parts = line.split(/\s+/)
    }
    if (parts.length < 2) return null

    return {
      name: parts[0] || "",
      id: parts[1] || "",
      version: parts[2] || "",
      origin: parts[3] || ""
    }
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">fp") && !searchText.startsWith(">flatpak")) return []

    var prefix = searchText.startsWith(">flatpak") ? ">flatpak" : ">fp"
    var query = searchText.slice(prefix.length).trim()

    if (query === "" || query === "list") {
      return [{ name: "Open Flatpak Manager", description: "Manage installed flatpaks, browse, update, and more", icon: "package", isTablerIcon: true, onActivate: function() { openPanel() } }]
    }

    var parts = query.split(/\s+/)
    var cmd = parts[0].toLowerCase()
    var arg = parts.slice(1).join(" ")

    if (cmd === "install" && arg) return makeSearchResults(arg)
    if (cmd === "update" && arg) return makeSearchResults(arg)
    if (cmd === "run" && arg) return makeSearchResults(arg)
    if (cmd === "kill" && arg) return makeRunningResults(arg)
    if (cmd === "uninstall" && arg) return makeSearchResults(arg)

    if (["install", "update", "run", "uninstall"].indexOf(cmd) !== -1 && !arg) {
      return [{
        name: "Enter flatpak name",
        description: "Type a flatpak name after '" + cmd + "'",
        icon: "alert-circle",
        isTablerIcon: true,
        onActivate: function() {}
      }]
    }

    return makeSearchResults(query)
  }

  function makeBrowseResults() {
    var results = []
    var limit = Math.min(installedFlatpaks.length, 50)
    for (var i = 0; i < limit; i++) {
      results.push(makeFlatpakResult(installedFlatpaks[i]))
    }
    if (results.length === 0 && loaded) {
      return [{ name: "No flatpaks installed", description: "Install flatpaks using >fp install", icon: "package-off", isTablerIcon: true, onActivate: function() {} }]
    }
    return results
  }

  function makeSearchResults(query) {
    if (!loaded) return [{ name: "Loading...", description: "Fetching flatpaks", icon: "loader", isTablerIcon: true, onActivate: function() {} }]

    var q = query.toLowerCase()
    var matched = []
    for (var i = 0; i < installedFlatpaks.length; i++) {
      var fp = installedFlatpaks[i]
      if ((fp.name || "").toLowerCase().indexOf(q) !== -1 ||
          (fp.id || "").toLowerCase().indexOf(q) !== -1) {
        matched.push(fp)
      }
    }
    if (matched.length === 0) {
      return [{ name: "No match: " + query, description: "No flatpaks found", icon: "search-off", isTablerIcon: true, onActivate: function() {} }]
    }
    var results = []
    for (var j = 0; j < Math.min(matched.length, 20); j++) {
      results.push(makeFlatpakResult(matched[j]))
    }
    return results
  }

  function makeRunningResults(query) {
    if (!loaded) return [{ name: "Loading...", description: "Fetching running flatpaks", icon: "loader", isTablerIcon: true, onActivate: function() {} }]

    var q = query.toLowerCase()
    var matched = []
    for (var i = 0; i < installedFlatpaks.length; i++) {
      var fp = installedFlatpaks[i]
      if ((fp.name || "").toLowerCase().indexOf(q) !== -1 ||
          (fp.id || "").toLowerCase().indexOf(q) !== -1) {
        matched.push(fp)
      }
    }
    if (matched.length === 0) {
      return [{ name: "No match: " + query, description: "No flatpaks found", icon: "search-off", isTablerIcon: true, onActivate: function() {} }]
    }
    var results = []
    for (var j = 0; j < Math.min(matched.length, 20); j++) {
      results.push(makeActionResult(matched[j], "run"))
    }
    return results
  }

  function makeFlatpakResult(fp) {
    return {
      name: fp.name || fp.id,
      description: fp.id + (fp.version ? " — v" + fp.version : "") + (fp.origin ? " — " + fp.origin : ""),
      icon: "package",
      isTablerIcon: true,
      provider: root,
      onActivate: function() {
        pluginApi.withCurrentScreen(function(screen) {
          pluginApi.pluginSettings._selectedFlatpak = fp
          pluginApi.pluginSettings._panelMode = "installed"
          pluginApi.openPanel(screen)
        })
        launcher.close()
      },
      actions: [
        {
          name: "Run",
          icon: "player-play",
          isTablerIcon: true,
          onActivate: function() {
            runFlatpak(fp.id, function(success) {
              ToastService.showNotice(success ? fp.name + " launched" : fp.name + " launch failed")
            })
          }
        },
        {
          name: "Uninstall",
          icon: "trash",
          isTablerIcon: true,
          onActivate: function() {
            uninstallFlatpak(fp.id, function(success) {
              ToastService.showNotice(success ? fp.name + " uninstalled" : fp.name + " uninstall failed")
              refreshInstalled()
            })
          }
        }
      ]
    }
  }

  function makeActionResult(fp, action) {
    var iconMap = { install: "download", update: "refresh", run: "player-play", uninstall: "trash", kill: "player-stop" }
    return {
      name: fp.name || fp.id,
      description: action + " — " + (fp.version || fp.id),
      icon: iconMap[action] || "package",
      isTablerIcon: true,
      provider: root,
      onActivate: function() {
        if (action === "run") {
          runFlatpak(fp.id, function(success) {
            ToastService.showNotice(success ? fp.name + " launched" : fp.name + " launch failed")
          })
        } else if (action === "install") {
          installFlatpak(fp.id, function(success) {
            ToastService.showNotice(success ? fp.name + " installed" : fp.name + " install failed")
            refreshInstalled()
          })
        } else if (action === "uninstall") {
          uninstallFlatpak(fp.id, function(success) {
            ToastService.showNotice(success ? fp.name + " uninstalled" : fp.name + " uninstall failed")
            refreshInstalled()
          })
        } else if (action === "update") {
          updateFlatpak(fp.id, function(success) {
            ToastService.showNotice(success ? fp.name + " updated" : fp.name + " update failed")
            refreshInstalled()
          })
        }
        launcher.close()
      }
    }
  }

  Process {
    id: actionProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (root._actionCallback) {
        root._actionCallback(exitCode === 0)
        root._actionCallback = null
      }
    }
  }

  property var _actionCallback: null

  function runFlatpak(id, cb) {
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " run '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function installFlatpak(id, cb) {
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " install -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function uninstallFlatpak(id, cb) {
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " uninstall -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function updateFlatpak(id, cb) {
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " update -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function openPanel() {
    if (!pluginApi) return
    pluginApi.withCurrentScreen(function(screen) {
      pluginApi.pluginSettings._panelMode = "installed"
      pluginApi.pluginSettings._selectedFlatpak = null
      pluginApi.openPanel(screen)
    })
    launcher.close()
  }
}
