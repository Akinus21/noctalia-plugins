import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var launcher: null

  property string name: "Systemd Services"
  property string supportedLayouts: "list"
  property bool handleSearch: false
  property bool supportsAutoPaste: false

  property bool showsCategories: false
  property string selectedCategory: "all"
  property var categories: ["all"]
  property var categoryIcons: ({ "all": "server" })

  property var units: []
  property bool loaded: false
  property bool fetching: false

  property string unitBuffer: ""

  Process {
    id: listProcess

    stdout: SplitParser {
      onRead: function(data) { root.unitBuffer += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("SystemdProvider", "stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      fetching = false
      parseUnits(unitBuffer)
      unitBuffer = ""
    }
  }

  function init() {
    Logger.i("SystemdProvider", "Initializing")
    refreshUnits()
  }

  function onOpened() {
    refreshUnits()
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">svc")
  }

  function commands() {
    return [
      {
        "name": ">svc",
        "description": pluginApi?.tr("launcher.searchPlaceholder") || "Search and manage systemd units",
        "icon": "server",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc ") }
      },
      {
        "name": ">svc start",
        "description": pluginApi?.tr("commands.start") || "Start a unit",
        "icon": "player-play",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc start ") }
      },
      {
        "name": ">svc stop",
        "description": pluginApi?.tr("commands.stop") || "Stop a unit",
        "icon": "player-stop",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc stop ") }
      },
      {
        "name": ">svc restart",
        "description": pluginApi?.tr("commands.restart") || "Restart a unit",
        "icon": "refresh",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc restart ") }
      },
      {
        "name": ">svc enable",
        "description": pluginApi?.tr("commands.enable") || "Enable on boot",
        "icon": "check",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc enable ") }
      },
      {
        "name": ">svc disable",
        "description": pluginApi?.tr("commands.disable") || "Disable from boot",
        "icon": "x",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc disable ") }
      },
      {
        "name": ">svc logs",
        "description": "Show recent logs for a unit",
        "icon": "file-text",
        "isTablerIcon": true,
        "onActivate": function() { launcher.setSearchText(">svc logs ") }
      },
      {
        "name": ">svc new",
        "description": pluginApi?.tr("commands.new") || "Create new unit",
        "icon": "plus",
        "isTablerIcon": true,
        "onActivate": function() { openCreatePanel() }
      }
    ]
  }

  function refreshUnits() {
    if (fetching) return
    fetching = true
    unitBuffer = ""
    listProcess.command = [
      "sh", "-c",
      "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && " +
      "systemctl --user list-units --all --no-pager " +
      "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope " +
      "--format=json 2>/dev/null || echo '[]'"
    ]
    listProcess.running = true
  }

  function parseUnits(raw) {
    if (!raw || raw.trim().length === 0) {
      loaded = true
      return
    }
    try {
      var data = JSON.parse(raw.trim())
      var mapped = []
      for (var i = 0; i < data.length; i++) {
        var u = data[i]
        mapped.push({
          name: u.name || "",
          type: u.unitType || "",
          loadState: u.loadState || "",
          activeState: u.activeState || "",
          subState: u.subState || "",
          description: u.description || "",
          scope: "user"
        })
      }
      root.units = mapped
      root.loaded = true
      if (launcher) launcher.updateResults()
    } catch (e) {
      Logger.e("SystemdProvider", "Parse error:", e, "raw:", raw.substring(0, 200))
      root.loaded = true
    }
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">svc")) return []

    var query = searchText.slice(4).trim()
    if (query === "") {
      return makeBrowseResults()
    }

    var parts = query.split(/\s+/)
    var cmd = parts[0].toLowerCase()
    var arg = parts.slice(1).join(" ")

    if (cmd === "start" && arg) return makeActionResults("start", arg)
    if (cmd === "stop" && arg) return makeActionResults("stop", arg)
    if (cmd === "restart" && arg) return makeActionResults("restart", arg)
    if (cmd === "enable" && arg) return makeActionResults("enable", arg)
    if (cmd === "disable" && arg) return makeActionResults("disable", arg)
    if (cmd === "logs" && arg) return makeLogsResults(arg)

    if (["start", "stop", "restart", "enable", "disable", "logs"].indexOf(cmd) !== -1 && !arg) {
      return [{
        name: "Enter unit name",
        description: "Type a unit name after '" + cmd + "'",
        icon: "alert-circle",
        isTablerIcon: true,
        onActivate: function() {}
      }]
    }

    if (cmd === "new") {
      openCreatePanel()
      return []
    }

    return makeSearchResults(query)
  }

  function makeBrowseResults() {
    var results = []
    var limit = Math.min(units.length, 50)
    for (var i = 0; i < limit; i++) {
      results.push(makeUnitResult(units[i]))
    }
    if (results.length === 0 && loaded) {
      return [{ name: "No units found", description: "No systemd units in user session", icon: "server-off", isTablerIcon: true, onActivate: function() {} }]
    }
    return results
  }

  function makeSearchResults(query) {
    if (!loaded) return [{ name: "Loading...", description: "Fetching units", icon: "loader", isTablerIcon: true, onActivate: function() {} }]

    var q = query.toLowerCase()
    var matched = []
    for (var i = 0; i < units.length; i++) {
      if ((units[i].name || "").toLowerCase().indexOf(q) !== -1) {
        matched.push(units[i])
      }
    }
    if (matched.length === 0) {
      return [{ name: "No match: " + query, description: "No units found", icon: "search-off", isTablerIcon: true, onActivate: function() {} }]
    }
    var results = []
    for (var j = 0; j < Math.min(matched.length, 20); j++) {
      results.push(makeUnitResult(matched[j]))
    }
    return results
  }

  function makeActionResults(action, query) {
    if (!loaded) return [{ name: "Loading...", description: "Fetching units", icon: "loader", isTablerIcon: true, onActivate: function() {} }]

    var q = query.toLowerCase()
    var matched = []
    for (var i = 0; i < units.length; i++) {
      if ((units[i].name || "").toLowerCase().indexOf(q) !== -1) {
        matched.push(units[i])
      }
    }
    if (matched.length === 0) {
      return [{ name: "No match: " + query, description: "No units found for " + action, icon: "search-off", isTablerIcon: true, onActivate: function() {} }]
    }
    var results = []
    for (var j = 0; j < Math.min(matched.length, 20); j++) {
      results.push(makeActionResult(matched[j], action))
    }
    return results
  }

  function makeLogsResults(query) {
    if (!loaded) return [{ name: "Loading...", description: "Fetching units", icon: "loader", isTablerIcon: true, onActivate: function() {} }]

    var q = query.toLowerCase()
    var matched = []
    for (var i = 0; i < units.length; i++) {
      if ((units[i].name || "").toLowerCase().indexOf(q) !== -1) {
        matched.push(units[i])
      }
    }
    if (matched.length === 0) {
      return [{ name: "No match: " + query, description: "No units found", icon: "search-off", isTablerIcon: true, onActivate: function() {} }]
    }
    var results = []
    for (var j = 0; j < Math.min(matched.length, 5); j++) {
      results.push(makeLogsResult(matched[j]))
    }
    return results
  }

  function makeUnitResult(u) {
    var isActive = u.activeState === "active"
    var subtitle = u.activeState + " / " + u.subState + (u.description ? " — " + u.description : "")

    return {
      name: u.name,
      description: subtitle,
      icon: isActive ? "player-play" : "player-stop",
      isTablerIcon: true,
      provider: root,
      onActivate: function() {
        pluginApi.withCurrentScreen(function(screen) {
          pluginApi.pluginSettings._selectedUnit = u
          pluginApi.pluginSettings._panelMode = "view"
          pluginApi.openPanel(screen)
        })
        launcher.close()
      },
      actions: [
        {
          name: isActive ? "Stop" : "Start",
          icon: isActive ? "player-stop" : "player-play",
          isTablerIcon: true,
          onActivate: function() {
            var action = isActive ? "stop" : "start"
            runUnitAction(u.name, action, function(success) {
              ToastService.showNotice(success ? u.name + " " + action + "ed" : u.name + " " + action + " failed")
              refreshUnits()
            })
          }
        },
        {
          name: "Restart",
          icon: "refresh",
          isTablerIcon: true,
          onActivate: function() {
            runUnitAction(u.name, "restart", function(success) {
              ToastService.showNotice(success ? u.name + " restarted" : u.name + " restart failed")
              refreshUnits()
            })
          }
        },
        {
          name: "Logs",
          icon: "file-text",
          isTablerIcon: true,
          onActivate: function() {
            pluginApi.withCurrentScreen(function(screen) {
              pluginApi.pluginSettings._selectedUnit = u
              pluginApi.pluginSettings._panelMode = "logs"
              pluginApi.openPanel(screen)
            })
            launcher.close()
          }
        }
      ]
    }
  }

  function makeActionResult(u, action) {
    var iconMap = { start: "player-play", stop: "player-stop", restart: "refresh", enable: "check", disable: "x", logs: "file-text" }
    return {
      name: u.name,
      description: action + " — " + u.activeState + " / " + u.subState,
      icon: iconMap[action] || "player-play",
      isTablerIcon: true,
      provider: root,
      onActivate: function() {
        runUnitAction(u.name, action, function(success) {
          ToastService.showNotice(success ? u.name + " " + action + "ed" : u.name + " " + action + " failed")
          refreshUnits()
          launcher.close()
        })
      }
    }
  }

  function makeLogsResult(u) {
    return {
      name: u.name + " logs",
      description: u.activeState + " — " + u.description,
      icon: "file-text",
      isTablerIcon: true,
      provider: root,
      onActivate: function() {
        pluginApi.withCurrentScreen(function(screen) {
          pluginApi.pluginSettings._selectedUnit = u
          pluginApi.pluginSettings._panelMode = "logs"
          pluginApi.openPanel(screen)
        })
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

  function runUnitAction(name, action, cb) {
    root._actionCallback = cb
    actionProcess.command = [
      "sh", "-c",
      "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && " +
      "systemctl --user " + action + " '" + name + "'"
    ]
    actionProcess.running = true
  }

  function openCreatePanel() {
    if (!pluginApi) return
    pluginApi.withCurrentScreen(function(screen) {
      pluginApi.pluginSettings._panelMode = "create"
      pluginApi.pluginSettings._editUnit = null
      pluginApi.openPanel(screen)
    })
    launcher.close()
  }
}