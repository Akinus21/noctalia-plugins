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

  readonly property var _supportedUnitTypes: ["service", "timer", "socket", "path", "mount", "automount", "swap", "target", "slice", "scope"]

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

  function refreshUnits() {
    loading = true
    errorMessage = ""
    listUnitsTimer.start()
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

  Timer {
    id: listUnitsTimer
    interval: 50
    onTriggered: {
      var args = ["systemctl", "--user", "list-units", "--all", "--no-pager",
                  "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope",
                  "--format=json"]
      listUnitsProcess.command = args
      listUnitsProcess.running = true
    }
  }

  function parseUnitsOutput(out, err, exitCode) {
    loading = false
    if (exitCode !== 0 && !out) {
      errorMessage = err || "Failed to list units"
      return
    }
    try {
      var data = JSON.parse(out)
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

  function startUnit(name, cb) {
    runSystemctl(["systemctl", "--user", "start", name], cb)
  }

  function stopUnit(name, cb) {
    runSystemctl(["systemctl", "--user", "stop", name], cb)
  }

  function restartUnit(name, cb) {
    runSystemctl(["systemctl", "--user", "restart", name], cb)
  }

  function enableUnit(name, cb) {
    runSystemctl(["systemctl", "--user", "enable", name], cb)
  }

  function disableUnit(name, cb) {
    runSystemctl(["systemctl", "--user", "disable", name], cb)
  }

  function createUnit(unitData, cb) {
    var content = generateUnitFile(unitData)
    var unitFilePath = root.userUnitDir + "/" + unitData.name + "." + unitData.type

    var writeProcess = Process {
      id: writeProcess
      environment: Object.assign({}, Qt.application.environment)

      onExited: function(exitCode, exitStatus) {
        if (exitCode === 0) {
          reloadDaemon(cb)
        } else {
          if (cb) cb(false, "Failed to write unit file")
        }
      }
    }

    writeProcess.command = ["sh", "-c",
      "mkdir -p '" + root.userUnitDir + "' && " +
      "printf '%s' " + JSON.stringify(content) + " > '" + unitFilePath + "'"
    ]
    writeProcess.running = true
  }

  function reloadDaemon(cb) {
    var reloadProcess = Process {
      id: reloadProcess
      environment: Object.assign({}, Qt.application.environment)

      onExited: function(exitCode, exitStatus) {
        if (cb) cb(exitCode === 0, exitCode === 0 ? "Unit created" : "Failed to reload daemon")
      }
    }
    reloadProcess.command = ["systemctl", "--user", "daemon-reload"]
    reloadProcess.running = true
  }

  function runSystemctl(args, cb) {
    var p = Process {
      id: systemctlProcess
      environment: Object.assign({}, Qt.application.environment)

      onExited: function(exitCode, exitStatus) {
        if (cb) cb(exitCode === 0, exitCode === 0 ? "Done" : "Failed")
      }
    }
    p.command = args
    p.running = true
  }

  function generateUnitFile(data) {
    var lines = []
    lines.push("[Unit]")
    if (data.description) {
      lines.push("Description=" + data.description)
    }
    if (data.type === "service") {
      if (data.execStart) {
        lines.push("ExecStart=" + data.execStart)
      }
      if (data.wantedBy && data.wantedBy.length > 0) {
        lines.push("[Install]")
        lines.push("WantedBy=" + data.wantedBy.join(" "))
      }
    } else if (data.type === "timer") {
      if (data.onCalendar) {
        lines.push("[Timer]")
        lines.push("OnCalendar=" + data.onCalendar)
      }
      if (data.wantedBy && data.wantedBy.length > 0) {
        lines.push("[Install]")
        lines.push("WantedBy=" + data.wantedBy.join(" "))
      }
    }
    return lines.join("\n") + "\n"
  }

  function getUnitLogs(name, lines, cb) {
    var p = Process {
      id: logProcess
      property string out: ""
      environment: Object.assign({}, Qt.application.environment)

      stdout: SplitParser {
        onRead: function(data) { logProcess.out += data + "\n" }
      }
      onExited: function(exitCode, exitStatus) {
        if (cb) cb(logProcess.out)
        logProcess.out = ""
      }
    }
    p.command = ["journalctl", "--user", "-u", name, "-n", String(lines), "--no-pager"]
    p.running = true
  }
}