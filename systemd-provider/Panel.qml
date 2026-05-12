import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: contentRect
  property real contentPreferredWidth: 700 * Style.uiScaleRatio
  property real contentPreferredHeight: 600 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  property var allUnits: []
  property bool loading: false
  property string errorMessage: ""
  property string selectedScope: "user"

  property var selectedUnit: pluginApi?.pluginSettings?._selectedUnit || null
  property string panelMode: pluginApi?.pluginSettings?._panelMode || "running"
  property string selectedTab: "processes"

  property string unitName: ""
  property string unitType: "service"
  property string execStart: ""
  property string unitDescription: ""
  property string onCalendar: ""
  property string wantedBy: "default.target"
  property bool createAsUser: true

  property string logOutput: ""
  property bool loadingLogs: false

  property var startupItems: []
  property bool loadingStartup: false

  Component.onCompleted: refreshAll()

  Process {
    id: listUnitsProcess
    stdout: SplitParser {
      onRead: function(data) { listUnitsProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("TaskManagerPanel", "list stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUnits(listUnitsProcess_out)
      listUnitsProcess_out = ""
    }
  }

  property string listUnitsProcess_out: ""

  Process {
    id: actionProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice(root._actionUnit + " " + root._actionName + "ed")
        refreshAll()
      } else {
        ToastService.showError(root._actionUnit + " " + root._actionName + " failed")
      }
      root._actionUnit = ""
      root._actionName = ""
    }
  }

  property string _actionUnit: ""
  property string _actionName: ""

  Process {
    id: logProcess
    stdout: SplitParser {
      onRead: function(data) { logProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { logProcess_out += "ERR: " + data + "\n" }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      logOutput = logProcess_out
      loadingLogs = false
      logProcess_out = ""
    }
  }

  property string logProcess_out: ""

  Process {
    id: createProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var reloadCmd = root.createAsUser
          ? "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && systemctl --user daemon-reload"
          : "systemctl daemon-reload"
        reloadProcess.command = ["sh", "-c", reloadCmd]
        reloadProcess.running = true
      } else {
        ToastService.showError("Failed to create unit file")
      }
    }
  }

  Process {
    id: reloadProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice("Unit created: " + root.unitName)
        root.unitName = ""
        root.execStart = ""
        root.unitDescription = ""
        root.onCalendar = ""
        root.wantedBy = "default.target"
        root.panelMode = "running"
        if (root.unitType === "timer") root.selectedTab = "timers"
        else root.selectedTab = "services"
        refreshAll()
      } else {
        ToastService.showError("Unit created but daemon-reload failed")
      }
    }
  }

  Rectangle {
    id: contentRect
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: "Task Manager"
          pointSize: Style.fontSizeXL
          font.weight: Font.Bold
          color: Color.mOnSurface
        }

        Item { Layout.fillWidth: true }

        NButton {
          text: "Refresh"
          outlined: true
          onClicked: refreshAll()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: "Processes"
          outlined: selectedTab !== "processes" || panelMode !== "running"
          onClicked: { panelMode = "running"; selectedTab = "processes" }
        }
        NButton {
          text: "Services"
          outlined: selectedTab !== "services" || panelMode !== "running"
          onClicked: { panelMode = "running"; selectedTab = "services" }
        }
        NButton {
          text: "Timers"
          outlined: selectedTab !== "timers" || panelMode !== "running"
          onClicked: { panelMode = "running"; selectedTab = "timers" }
        }
        NButton {
          text: "Startup"
          outlined: selectedTab !== "startup" || panelMode !== "running"
          onClicked: { panelMode = "running"; selectedTab = "startup"; loadStartupItems() }
        }
      }

      NText {
        visible: loading
        text: "Loading..."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        visible: errorMessage !== ""
        text: errorMessage
        color: Color.mError
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "running" && selectedTab === "processes"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          Repeater {
            id: processRepeater
            model: sortedProcesses

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 8
                  Layout.preferredHeight: 8
                  radius: 4
                  color: modelData.activeState === "active" ? "#4CAF50" : "#9E9E9E"
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: (modelData.activeState || "") + " / " + (modelData.subState || "") + (modelData.description ? " — " + modelData.description : "")
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: "Kill"
                  outlined: true
                  onClicked: {
                    var action = "kill"
                    runAction(modelData.name, action)
                  }
                }

                NButton {
                  text: "Logs"
                  outlined: true
                  onClicked: {
                    selectedUnit = modelData
                    panelMode = "logs"
                    loadLogs(modelData.name)
                  }
                }
              }
            }
          }
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "running" && selectedTab === "services"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NButton {
              text: "+ New Service"
              outlined: true
              onClicked: { unitType = "service"; panelMode = "create" }
            }

            Item { Layout.fillWidth: true }
          }

          Repeater {
            id: serviceRepeater
            model: sortedServices

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 8
                  Layout.preferredHeight: 8
                  radius: 4
                  color: modelData.activeState === "active" ? "#4CAF50" : "#9E9E9E"
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: (modelData.activeState || "") + " / " + (modelData.subState || "") + (modelData.description ? " — " + modelData.description : "")
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: modelData.activeState === "active" ? "Stop" : "Start"
                  outlined: true
                  onClicked: {
                    var action = modelData.activeState === "active" ? "stop" : "start"
                    runAction(modelData.name, action)
                  }
                }

                NButton {
                  text: "Restart"
                  outlined: true
                  onClicked: runAction(modelData.name, "restart")
                }

                NButton {
                  text: modelData.loadState === "enabled" ? "Disable" : "Enable"
                  outlined: true
                  onClicked: {
                    var action = modelData.loadState === "enabled" ? "disable" : "enable"
                    runAction(modelData.name, action)
                  }
                }

                NButton {
                  text: "Edit"
                  outlined: true
                  onClicked: editUnitFile(modelData.name, modelData.type)
                }

                NButton {
                  text: "Delete"
                  outlined: true
                  onClicked: deleteUnit(modelData.name, modelData.type)
                }

                NButton {
                  text: "Logs"
                  outlined: true
                  onClicked: {
                    selectedUnit = modelData
                    panelMode = "logs"
                    loadLogs(modelData.name)
                  }
                }
              }
            }
          }
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "running" && selectedTab === "timers"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NButton {
              text: "+ New Timer"
              outlined: true
              onClicked: { unitType = "timer"; panelMode = "create" }
            }

            Item { Layout.fillWidth: true }
          }

          Repeater {
            id: timerRepeater
            model: sortedTimers

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 8
                  Layout.preferredHeight: 8
                  radius: 4
                  color: modelData.activeState === "active" ? "#4CAF50" : "#9E9E9E"
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: (modelData.activeState || "") + " / " + (modelData.subState || "") + (modelData.description ? " — " + modelData.description : "")
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: modelData.activeState === "active" ? "Stop" : "Start"
                  outlined: true
                  onClicked: {
                    var action = modelData.activeState === "active" ? "stop" : "start"
                    runAction(modelData.name, action)
                  }
                }

                NButton {
                  text: "Restart"
                  outlined: true
                  onClicked: runAction(modelData.name, "restart")
                }

                NButton {
                  text: modelData.loadState === "enabled" ? "Disable" : "Enable"
                  outlined: true
                  onClicked: {
                    var action = modelData.loadState === "enabled" ? "disable" : "enable"
                    runAction(modelData.name, action)
                  }
                }

                NButton {
                  text: "Edit"
                  outlined: true
                  onClicked: editUnitFile(modelData.name, modelData.type)
                }

                NButton {
                  text: "Delete"
                  outlined: true
                  onClicked: deleteUnit(modelData.name, modelData.type)
                }

                NButton {
                  text: "Logs"
                  outlined: true
                  onClicked: {
                    selectedUnit = modelData
                    panelMode = "logs"
                    loadLogs(modelData.name)
                  }
                }
              }
            }
          }
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "running" && selectedTab === "startup"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NButton {
              text: "+ New Service"
              outlined: true
              onClicked: { unitType = "service"; panelMode = "create" }
            }

            Item { Layout.fillWidth: true }
          }

          Repeater {
            id: startupRepeater
            model: sortedStartupItems

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 8
                  Layout.preferredHeight: 8
                  radius: 4
                  color: modelData.state === "enabled" ? "#4CAF50" : "#9E9E9E"
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.state || ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: modelData.state === "enabled" ? "Disable" : "Enable"
                  outlined: true
                  onClicked: {
                    var action = modelData.state === "enabled" ? "disable" : "enable"
                    runEnableDisable(modelData.name, action)
                  }
                }

                NButton {
                  text: "Edit"
                  outlined: true
                  onClicked: editStartupFile(modelData.name, modelData.type)
                }

                NButton {
                  text: "Delete"
                  outlined: true
                  onClicked: deleteStartupItem(modelData.name, modelData.type)
                }
              }
            }
          }
        }
      }

      NText {
        visible: !loading && panelMode === "running" && selectedTab === "processes" && sortedProcesses.length === 0
        text: "No processes"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        visible: !loading && panelMode === "running" && selectedTab === "services" && sortedServices.length === 0
        text: "No services"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        visible: !loading && panelMode === "running" && selectedTab === "timers" && sortedTimers.length === 0
        text: "No timers"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        visible: !loadingStartup && panelMode === "running" && selectedTab === "startup" && startupItems.length === 0
        text: "No startup items"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "create"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          NText {
            text: unitType === "timer" ? "Create New Timer" : "Create New Service"
            font.weight: Font.Bold
            pointSize: Style.fontSizeL
            Layout.fillWidth: true
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Unit Name"
            placeholderText: "my-service"
            text: root.unitName
            onTextChanged: root.unitName = text
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Exec Start"
            placeholderText: unitType === "timer" ? "/usr/bin/my-script.sh" : "/usr/bin/my-daemon"
            text: root.execStart
            onTextChanged: root.execStart = text
            visible: unitType === "service"
          }

          NTextInput {
            Layout.fillWidth: true
            label: "On Calendar (timer interval)"
            description: "e.g. *:*:0 (every minute), daily, weekly, *:*:0/15 (every 15 min)"
            placeholderText: "hourly"
            text: root.onCalendar
            onTextChanged: root.onCalendar = text
            visible: unitType === "timer"
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Description"
            placeholderText: "My systemd service"
            text: root.unitDescription
            onTextChanged: root.unitDescription = text
          }

          NTextInput {
            Layout.fillWidth: true
            label: "Wanted By"
            placeholderText: "default.target"
            text: root.wantedBy
            onTextChanged: root.wantedBy = text
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: "Scope"
              color: Color.mOnSurface
              Layout.preferredWidth: 100
            }

            NButton {
              text: "User"
              outlined: !createAsUser
              onClicked: createAsUser = true
            }
            NButton {
              text: "System (root)"
              outlined: createAsUser
              onClicked: createAsUser = false
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NButton {
              text: "Create"
              onClicked: createUnit()
            }

            NButton {
              text: "Cancel"
              outlined: true
              onClicked: { panelMode = "running"; unitName = ""; execStart = ""; unitDescription = ""; onCalendar = ""; wantedBy = "default.target" }
            }
          }
        }
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "logs"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NText {
              text: (selectedUnit?.name || "") + " — Logs"
              font.weight: Font.Bold
              pointSize: Style.fontSizeL
              Layout.fillWidth: true
            }

            NButton {
              text: "Back"
              outlined: true
              onClicked: { panelMode = "running"; logOutput = "" }
            }
            NButton {
              text: "Reload"
              outlined: true
              onClicked: { if (selectedUnit) loadLogs(selectedUnit.name) }
            }
          }

          NText {
            visible: loadingLogs
            text: "Loading logs..."
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }

          NText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: logOutput || "No logs"
            color: Color.mOnSurface
            pointSize: Style.fontSizeXS
            font.family: "monospace"
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }

  property var sortedProcesses: {
    var result = []
    for (var i = 0; i < allUnits.length; i++) {
      var u = allUnits[i]
      if (u.type === "service" || u.type === "timer") {
        result.push(u)
      }
    }
    result.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return result
  }

  property var sortedServices: {
    var result = []
    for (var i = 0; i < allUnits.length; i++) {
      if (allUnits[i].type === "service") result.push(allUnits[i])
    }
    result.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return result
  }

  property var sortedTimers: {
    var result = []
    for (var i = 0; i < allUnits.length; i++) {
      if (allUnits[i].type === "timer") result.push(allUnits[i])
    }
    result.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return result
  }

  property var sortedStartupItems: {
    var result = startupItems.slice()
    result.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return result
  }

  function refreshAll() {
    loading = true
    errorMessage = ""
    listUnitsProcess_out = ""
    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    listUnitsProcess.command = [
      "sh", "-c",
      dbug + "systemctl " + (selectedScope === "system" ? "" : "--user") + " list-units --all --no-pager " +
      "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope 2>&1"
    ]
    listUnitsProcess.running = true
  }

  function parseUnits(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      allUnits = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.length < 60) continue
      if (line.indexOf("LOAD") !== -1 && line.indexOf("ACTIVE") !== -1 && line.indexOf("SUB") !== -1) continue
      if (line.indexOf("loaded units listed") !== -1) continue
      if (line.indexOf(".") === -1) continue
      var unit = parseUnitLine(line)
      if (unit.name) result.push(unit)
    }
    root.allUnits = result
    if (result.length === 0) {
      Logger.w("TaskManagerPanel", "No units parsed, raw sample:", raw.substring(0, 300))
    }
  }

  function parseUnitLine(line) {
    var trimmed = line.trim()
    var parts = trimmed.split(/\s+/)
    if (parts.length < 4) return { name: "" }

    var name = parts[0].replace(/\\x2d/g, "-").replace(/\\x20/g, " ")
    var loadState = parts[1]
    var activeState = parts[2]
    var subState = parts[3]
    var description = parts.slice(4).join(" ").replace(/\\x2d/g, "-").replace(/\\x20/g, " ")

    var dotIdx = name.lastIndexOf(".")
    var unitType = "service"
    if (dotIdx !== -1) {
      var suffix = name.substring(dotIdx + 1)
      if (suffix === "service" || suffix === "timer" || suffix === "socket" || suffix === "path" ||
          suffix === "mount" || suffix === "scope" || suffix === "target" || suffix === "slice" ||
          suffix === "automount" || suffix === "swap") {
        unitType = suffix
      }
    }

    return {
      name: name,
      type: unitType,
      loadState: loadState || "loaded",
      activeState: activeState || "inactive",
      subState: subState || "",
      description: description,
      scope: selectedScope
    }
  }

  function runAction(name, action) {
    root._actionUnit = name
    root._actionName = action
    var scope = selectedScope === "system" ? "" : "--user"
    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    actionProcess.command = [
      "sh", "-c",
      dbug + "systemctl " + scope + " " + action + " '" + name + "'"
    ]
    actionProcess.running = true
  }

  function deleteUnit(name, type) {
    root._actionUnit = name
    root._actionName = "delete"
    var scope = selectedScope === "system" ? "" : "--user"
    var targetDir = selectedScope === "system"
      ? "/etc/systemd/system"
      : (Quickshell.env("HOME") || "/root") + "/.config/systemd/user"

    var baseName = name.replace(/\.(service|timer)$/, "")
    var filesToDelete = "'" + targetDir + "/" + baseName + ".service'"

    if (type === "timer") {
      filesToDelete += " '" + targetDir + "/" + baseName + ".timer'"
    }

    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    deleteProcess.command = [
      "sh", "-c",
      "rm -f " + filesToDelete + " && " + dbug + "systemctl " + scope + " daemon-reload"
    ]
    deleteProcess.running = true
  }

  Process {
    id: deleteProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice(root._actionUnit + " deleted")
        refreshAll()
      } else {
        ToastService.showError(root._actionUnit + " delete failed")
      }
      root._actionUnit = ""
      root._actionName = ""
    }
  }

  function editUnitFile(name, type) {
    var scope = selectedScope === "system" ? "" : "--user"
    var targetDir = selectedScope === "system"
      ? "/etc/systemd/system"
      : (Quickshell.env("HOME") || "/root") + "/.config/systemd/user"
    var baseName = name.replace(/\.(service|timer)$/, "")
    var ext = type || (name.indexOf(".timer") !== -1 ? "timer" : "service")
    var filePath = targetDir + "/" + baseName + "." + ext
    Quickshell.execDetached(["xdg-open", filePath])
  }

  function editStartupFile(name, type) {
    var scope = selectedScope === "system" ? "" : "--user"
    var targetDir = selectedScope === "system"
      ? "/etc/systemd/system"
      : (Quickshell.env("HOME") || "/root") + "/.config/systemd/user"
    var filePath = targetDir + "/" + name
    Quickshell.execDetached(["xdg-open", filePath])
  }

  function deleteStartupItem(name, type) {
    deleteUnit(name, type)
  }

  function loadLogs(name) {
    loadingLogs = true
    logOutput = ""
    var scope = selectedScope === "system" ? "" : "--user"
    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    logProcess_out = ""
    logProcess.command = [
      "sh", "-c",
      dbug + "journalctl " + scope + " -u '" + name + "' -n 100 --no-pager 2>&1"
    ]
    logProcess.running = true
  }

  Process {
    id: listStartupProcess
    stdout: SplitParser {
      onRead: function(data) { listStartupProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("TaskManagerPanel", "startup stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseStartupItems(listStartupProcess_out)
      listStartupProcess_out = ""
    }
  }

  property string listStartupProcess_out: ""

  function loadStartupItems() {
    loadingStartup = true
    startupItems = []
    listStartupProcess_out = ""
    var scope = selectedScope === "system" ? "" : "--user"
    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    listStartupProcess.command = [
      "sh", "-c",
      dbug + "systemctl " + scope + " list-unit-files --all --no-pager 2>&1"
    ]
    listStartupProcess.running = true
  }

  function parseStartupItems(raw) {
    loadingStartup = false
    if (!raw || raw.trim().length === 0) {
      startupItems = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.length < 20) continue
      if (line.indexOf("UNIT FILE") !== -1) continue
      if (line.indexOf("listed") !== -1) continue
      var parts = line.trim().split(/\s+/)
      if (parts.length < 2) continue
      var name = parts[0]
      var state = parts[1]
      if (state === "enabled" || state === "enabled-runtime" || state === "linked" ||
          state === "linked-runtime" || state === "static" || state === "transient") {
        result.push({
          name: name,
          state: state,
          scope: selectedScope,
          type: name.indexOf(".") !== -1 ? name.split(".").pop() : "service"
        })
      }
    }
    startupItems = result
  }

  Process {
    id: enableDisableProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice(root._actionUnit + " " + root._actionName + "d")
        loadStartupItems()
      } else {
        ToastService.showError(root._actionUnit + " " + root._actionName + " failed")
      }
      root._actionUnit = ""
      root._actionName = ""
    }
  }

  function runEnableDisable(name, action) {
    root._actionUnit = name
    root._actionName = action
    var scope = selectedScope === "system" ? "" : "--user"
    var dbug = selectedScope === "system" ? "" : "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && "
    enableDisableProcess.command = [
      "sh", "-c",
      dbug + "systemctl " + scope + " " + action + " '" + name + "'"
    ]
    enableDisableProcess.running = true
  }

  function createUnit() {
    if (!root.unitName) {
      ToastService.showError("Unit name is required")
      return
    }

    var baseName = root.unitName.replace(/\.(service|timer)$/, "")
    var targetDir = root.createAsUser
      ? (Quickshell.env("HOME") || "/root") + "/.config/systemd/user"
      : "/etc/systemd/system"

    var installSection = ""
    if (root.wantedBy) {
      installSection = "\n[Install]\nWantedBy=" + root.wantedBy
    }

    if (root.unitType === "service") {
      if (!root.execStart) {
        ToastService.showError("Exec Start is required for services")
        return
      }
      var unitContent = "[Unit]\nDescription=" + (root.unitDescription || baseName) + "\n\n" +
        "[Service]\nExecStart=" + root.execStart + "\n" + installSection + "\n"
      createProcess.command = [
        "sh", "-c",
        "mkdir -p '" + targetDir + "' && " +
        "printf '%s' " + JSON.stringify(unitContent) + " > '" + targetDir + "/" + baseName + ".service'"
      ]
      createProcess.running = true
    } else if (root.unitType === "timer") {
      if (!root.onCalendar) {
        ToastService.showError("On Calendar schedule is required for timers")
        return
      }
      var timerContent = "[Unit]\nDescription=" + (root.unitDescription || baseName) + "\n\n" +
        "[Timer]\nOnCalendar=" + root.onCalendar + "\n" + installSection + "\n"
      var serviceContent = "[Unit]\nDescription=" + (root.unitDescription || baseName) + "\n\n" +
        "[Service]\nExecStart=" + (root.execStart || "/bin/true") + "\n"
      createProcess.command = [
        "sh", "-c",
        "mkdir -p '" + targetDir + "' && " +
        "printf '%s' " + JSON.stringify(timerContent) + " > '" + targetDir + "/" + baseName + ".timer' && " +
        "printf '%s' " + JSON.stringify(serviceContent) + " > '" + targetDir + "/" + baseName + ".service'"
      ]
      createProcess.running = true
    }
  }
}