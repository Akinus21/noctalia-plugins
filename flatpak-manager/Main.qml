import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property var installedFlatpaks: []
  property var runningFlatpaks: []
  property var updateableFlatpaks: []
  property var remotes: []
  property bool loading: false
  property string errorMessage: ""

  readonly property string userScopeFlag: "--user"
  readonly property string systemScopeFlag: "--system"

  IpcHandler {
    target: "plugin:flatpak-manager"

    function listInstalled() {
      refreshInstalled()
    }

    function listRunning() {
      refreshRunning()
    }

    function checkUpdates() {
      checkForUpdates()
    }
  }

  Process {
    id: listInstalledProcess

    stdout: SplitParser {
      onRead: function(data) { listInstalledProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakManager", "list stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseInstalledList(listInstalledProcess_out)
      listInstalledProcess_out = ""
    }
  }

  property string listInstalledProcess_out: ""

  Process {
    id: listRunningProcess

    stdout: SplitParser {
      onRead: function(data) { listRunningProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakManager", "running stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseRunningList(listRunningProcess_out)
      listRunningProcess_out = ""
    }
  }

  property string listRunningProcess_out: ""

  Process {
    id: listUpdatesProcess

    stdout: SplitParser {
      onRead: function(data) { listUpdatesProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakManager", "updates stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUpdatesList(listUpdatesProcess_out)
      listUpdatesProcess_out = ""
    }
  }

  property string listUpdatesProcess_out: ""

  Process {
    id: listRemotesProcess

    stdout: SplitParser {
      onRead: function(data) { listRemotesProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakManager", "remotes stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseRemotesList(listRemotesProcess_out)
      listRemotesProcess_out = ""
    }
  }

  property string listRemotesProcess_out: ""

  Process {
    id: actionProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (root._actionCallback) {
        root._actionCallback(exitCode === 0, root._actionName, exitCode)
        root._actionCallback = null
      }
      root._actionName = ""
    }
  }

  property string _actionName: ""
  property var _actionCallback: null

  Process {
    id: appstreamProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        if (pluginApi) {
          pluginApi.pluginSettings.appstreamUpdated = true
        }
        ToastService.showNotice("Appstream data updated")
      } else {
        ToastService.showError("Failed to update appstream data")
      }
    }
  }

  function getScopeFlag() {
    var scope = pluginApi?.pluginSettings?.defaultScope || "user"
    return scope === "system" ? systemScopeFlag : userScopeFlag
  }

  function refreshInstalled() {
    loading = true
    errorMessage = ""
    listInstalledProcess_out = ""
    var scope = getScopeFlag()
    listInstalledProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " list --app --columns=name,application,version,origin,runtime,size 2>&1"
    ]
    listInstalledProcess.running = true
  }

  function refreshRunning() {
    listRunningProcess_out = ""
    var scope = getScopeFlag()
    listRunningProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " ps 2>&1"
    ]
    listRunningProcess.running = true
  }

  function checkForUpdates() {
    loading = true
    errorMessage = ""
    listUpdatesProcess_out = ""
    var scope = getScopeFlag()
    listUpdatesProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " list --app --upgrades --columns=name,application,version,origin,runtime,size 2>&1"
    ]
    listUpdatesProcess.running = true
  }

  function refreshRemotes() {
    listRemotesProcess_out = ""
    var scope = getScopeFlag()
    listRemotesProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " remote-list --columns=name,url,title 2>&1"
    ]
    listRemotesProcess.running = true
  }

  function parseInstalledList(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      installedFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("ID") !== -1) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    installedFlatpaks = result
    Logger.i("FlatpakManager", "Parsed", result.length, "installed flatpaks")
  }

  function parseRunningList(raw) {
    if (!raw || raw.trim().length === 0) {
      runningFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      var parts = line.split(/\s+/)
      if (parts.length >= 3) {
        result.push({
          pid: parts[0],
          name: parts[1],
          id: parts[2]
        })
      }
    }
    runningFlatpaks = result
    Logger.i("FlatpakManager", "Parsed", result.length, "running flatpaks")
  }

  function parseUpdatesList(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      updateableFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("ID") !== -1) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    updateableFlatpaks = result
    Logger.i("FlatpakManager", "Parsed", result.length, "updateable flatpaks")
  }

  function parseRemotesList(raw) {
    if (!raw || raw.trim().length === 0) {
      remotes = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("URL") !== -1) continue
      var parts = line.split(/\s+/)
      if (parts.length >= 2) {
        result.push({
          name: parts[0],
          url: parts[1]
        })
      }
    }
    remotes = result
    Logger.i("FlatpakManager", "Parsed", result.length, "remotes")
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
      application: parts[1] || "",
      version: parts[2] || "",
      origin: parts[3] || "",
      runtime: parts[4] || "",
      size: parts[5] || ""
    }
  }

  function installFlatpak(id, cb) {
    root._actionName = "install"
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
    root._actionName = "uninstall"
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
    root._actionName = "update"
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " update -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function updateAllFlatpaks(cb) {
    root._actionName = "update-all"
    root._actionCallback = cb
    var scope = getScopeFlag()
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " update -y 2>&1"
    ]
    actionProcess.running = true
  }

  function runFlatpak(id, cb) {
    root._actionName = "run"
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " run '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function killFlatpak(pid, cb) {
    root._actionName = "kill"
    root._actionCallback = cb
    var escapedPid = pid.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak kill '" + escapedPid + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function addRemote(name, url, cb) {
    root._actionName = "add-remote"
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedName = name.replace(/'/g, "'\\''")
    var escapedUrl = url.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " remote-add --if-not-exists '" + escapedName + "' '" + escapedUrl + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function removeRemote(name, cb) {
    root._actionName = "remove-remote"
    root._actionCallback = cb
    var scope = getScopeFlag()
    var escapedName = name.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " remote-delete '" + escapedName + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function updateAppstream(cb) {
    root._actionCallback = cb
    appstreamProcess.command = [
      "sh", "-c",
      "flatpak update --appstream 2>&1"
    ]
    appstreamProcess.running = true
  }

  function searchFlatpaks(query, cb) {
    root._searchCallback = cb
    searchProcess_out = ""
    var scope = getScopeFlag()
    searchProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " search '" + query.replace(/'/g, "'\\''") + "' 2>&1"
    ]
    searchProcess.running = true
  }

  Process {
    id: searchProcess

    stdout: SplitParser {
      onRead: function(data) { searchProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakManager", "search stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseSearchResults(searchProcess_out)
      searchProcess_out = ""
    }
  }

  property string searchProcess_out: ""
  property var _searchCallback: null

  function parseSearchResults(raw) {
    if (!raw || raw.trim().length === 0) {
      if (root._searchCallback) {
        root._searchCallback([])
        root._searchCallback = null
      }
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    if (root._searchCallback) {
      root._searchCallback(result)
      root._searchCallback = null
    }
  }
}
