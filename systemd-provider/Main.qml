import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property var units: []
  property bool loading: false
  property string errorMessage: ""

  readonly property string userUnitDir: (Quickshell.env("HOME") || "/root") + "/.config/systemd/user"
  readonly property string systemUnitDir: "/etc/systemd/system"

  IpcHandler {
    target: "plugin:systemd-provider"

    function list() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(function(screen) {
          refreshUnits()
        })
      }
    }
  }

  Process {
    id: listUnitsProcess
    property string out: ""
    property string err: ""

    stdout: SplitParser {
      onRead: function(data) { listUnitsProcess.out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { listUnitsProcess.err += data + "\n" }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUnitsOutput(listUnitsProcess.out, listUnitsProcess.err, exitCode)
      listUnitsProcess.out = ""
      listUnitsProcess.err = ""
    }
  }

  Process {
    id: writeUnitProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        reloadDaemon()
      } else {
        Logger.e("SystemdMain", "Failed to write unit file, exit:", exitCode)
      }
    }
  }

  Process {
    id: reloadDaemonProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      Logger.i("SystemdMain", "daemon-reload done, exit:", exitCode)
    }
  }

  Process {
    id: systemctlProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      Logger.i("SystemdMain", "systemctl exit:", exitCode)
    }
  }

  Process {
    id: logProcess
    property string out: ""

    stdout: SplitParser {
      onRead: function(data) { logProcess.out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("SystemdMain", "log stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      var result = logProcess.out
      logProcess.out = ""
      if (root._logCallback) {
        root._logCallback(result)
        root._logCallback = null
      }
    }
  }

  property var _logCallback: null

  function refreshUnits() {
    loading = true
    errorMessage = ""
    listUnitsProcess.out = ""
    listUnitsProcess.err = ""
    listUnitsProcess.command = [
      "sh", "-c",
      "systemctl --user list-units --all --no-pager " +
      "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope " +
      "--format=json 2>/dev/null || echo '[]'"
    ]
    listUnitsProcess.running = true
  }

  function parseUnitsOutput(out, err, exitCode) {
    loading = false
    if (exitCode !== 0 && !out) {
      errorMessage = err || "Failed to list units"
      return
    }
    try {
      var data = JSON.parse(out.trim())
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
    } catch (e) {
      errorMessage = "Failed to parse units: " + e
    }
  }

  function startUnit(name) {
    runSystemctl("--user", "start", name)
  }

  function stopUnit(name) {
    runSystemctl("--user", "stop", name)
  }

  function restartUnit(name) {
    runSystemctl("--user", "restart", name)
  }

  function enableUnit(name) {
    runSystemctl("--user", "enable", name)
  }

  function disableUnit(name) {
    runSystemctl("--user", "disable", name)
  }

  function runSystemctl(scope, action, name) {
    var cmd = scope
      ? "systemctl " + scope + " " + action + " '" + name + "'"
      : "systemctl " + action + " '" + name + "'"
    systemctlProcess.command = ["sh", "-c", cmd]
    systemctlProcess.running = true
  }

  function reloadDaemon() {
    reloadDaemonProcess.command = ["systemctl", "--user", "daemon-reload"]
    reloadDaemonProcess.running = true
  }

  function createUnitFile(name, type, execStart, description, wantedBy, asUser) {
    var targetDir = asUser
      ? root.userUnitDir
      : root.systemUnitDir

    var installSection = wantedBy ? "\n[Install]\nWantedBy=" + wantedBy : ""

    var unitContent = "[Unit]\nDescription=" + (description || name) + "\n\n"
    if (type === "service") {
      unitContent += "[Service]\nExecStart=" + (execStart || "/bin/true") + installSection + "\n"
    } else if (type === "timer") {
      unitContent += "[Timer]\nOnCalendar=hourly" + installSection + "\n"
    }

    var cmd = "mkdir -p '" + targetDir + "' && " +
              "printf '%s' " + JSON.stringify(unitContent) + " > '" + targetDir + "/" + name + "." + type + "'"

    writeUnitProcess.command = ["sh", "-c", cmd]
    writeUnitProcess.running = true
    Logger.i("SystemdMain", "Creating unit:", name, "in", targetDir)
  }

  function getUnitLogs(name, lines, cb) {
    root._logCallback = cb
    logProcess.out = ""
    logProcess.command = [
      "sh", "-c",
      "journalctl --user -u '" + name + "' -n " + String(lines || 100) + " --no-pager 2>/dev/null || echo 'No logs'"
    ]
    logProcess.running = true
  }
}