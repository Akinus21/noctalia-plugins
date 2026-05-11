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

  property var units: []
  property bool loading: false
  property string errorMessage: ""
  property string selectedScope: "user"

  property var selectedUnit: pluginApi?.pluginSettings?._selectedUnit || null
  property string panelMode: pluginApi?.pluginSettings?._panelMode || "view"

  property string unitName: ""
  property string unitType: "service"
  property string execStart: ""
  property string unitDescription: ""
  property string onCalendar: ""
  property string wantedBy: "default.target"
  property bool createAsUser: true

  property string logOutput: ""
  property bool loadingLogs: false

  Component.onCompleted: refreshUnits()

  Process {
    id: listUnitsProcess
    stdout: SplitParser {
      onRead: function(data) { listUnitsProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("SystemdPanel", "list stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUnits(listUnitsProcess_out)
      listUnitsProcess_out = ""
    }
  }

  property string listUnitsProcess_out: ""

  Process {
    id: listSystemUnitsProcess
    stdout: SplitParser {
      onRead: function(data) { listSystemUnitsProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("SystemdPanel", "system list stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUnits(listSystemUnitsProcess_out)
      listSystemUnitsProcess_out = ""
    }
  }

  property string listSystemUnitsProcess_out: ""

  Process {
    id: actionProcess
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice(root._actionUnit + " " + root._actionName + "ed")
        if (selectedScope === "user") refreshUnits()
        else refreshUnitsSystem()
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
        root.panelMode = "view"
        if (root.createAsUser) refreshUnits()
        else refreshUnitsSystem()
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
          text: pluginApi?.tr("panel.title") || "Systemd Services"
          pointSize: Style.fontSizeXL
          font.weight: Font.Bold
          color: Color.mOnSurface
        }

        Item { Layout.fillWidth: true }

        NButton {
          text: "Refresh"
          outlined: true
          onClicked: refreshUnits()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: "User"
          outlined: selectedScope !== "user"
          onClicked: { selectedScope = "user"; refreshUnits() }
        }
        NButton {
          text: "System"
          outlined: selectedScope !== "system"
          onClicked: { selectedScope = "system"; refreshUnitsSystem() }
        }
      }

      NText {
        visible: loading
        text: pluginApi?.tr("panel.loading") || "Loading units..."
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

      NText {
        visible: !loading && units.length === 0 && errorMessage === ""
        text: pluginApi?.tr("panel.noUnits") || "No units found"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: panelMode === "view" || panelMode === "logs"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          Repeater {
            id: unitRepeater
            model: panelMode === "logs" && selectedUnit ? [selectedUnit] : units

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
        visible: panelMode === "create" || panelMode === "edit"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          NText {
            text: panelMode === "create" ? "Create New Unit" : "Edit Unit"
            font.weight: Font.Bold
            pointSize: Style.fontSizeL
            Layout.fillWidth: true
          }

          NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("unit.name") || "Unit Name"
            placeholderText: "my-service"
            text: root.unitName
            enabled: panelMode === "create"
            onTextChanged: root.unitName = text
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("unit.type") || "Type"
              color: Color.mOnSurface
              Layout.preferredWidth: 100
            }

            NButton {
              text: "Service"
              outlined: unitType !== "service"
              onClicked: unitType = "service"
            }
            NButton {
              text: "Timer"
              outlined: unitType !== "timer"
              onClicked: unitType = "timer"
            }
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
              text: pluginApi?.tr("unit.scope") || "Scope"
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
              onClicked: panelMode = "view"
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
              onClicked: { panelMode = "view"; logOutput = "" }
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

  function refreshUnits() {
    loading = true
    errorMessage = ""
    listUnitsProcess_out = ""
    listUnitsProcess.command = [
      "sh", "-c",
      "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && " +
      "systemctl --user list-units --all --no-pager " +
      "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope 2>&1"
    ]
    listUnitsProcess.running = true
  }

  function refreshUnitsSystem() {
    loading = true
    errorMessage = ""
    listSystemUnitsProcess_out = ""
    listSystemUnitsProcess.command = [
      "sh", "-c",
      "systemctl list-units --all --no-pager " +
      "--type=service,timer,socket,path,mount,automount,swap,target,slice,scope 2>&1"
    ]
    listSystemUnitsProcess.running = true
  }

  function parseUnits(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      units = []
      return
    }
    parseUnitsFromText(raw)
  }

  function parseUnitsFromText(raw) {
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
    root.units = result
    if (result.length === 0) {
      Logger.w("SystemdPanel", "No units parsed from text output, raw sample:", raw.substring(0, 300))
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
    actionProcess.command = [
      "sh", "-c",
      "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && " +
      "systemctl " + scope + " " + action + " '" + name + "'"
    ]
    actionProcess.running = true
  }

  function loadLogs(name) {
    loadingLogs = true
    logOutput = ""
    var scope = selectedScope === "system" ? "" : "--user"
    logProcess_out = ""
    logProcess.command = [
      "sh", "-c",
      "export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus && " +
      "journalctl " + scope + " -u '" + name + "' -n 100 --no-pager 2>&1"
    ]
    logProcess.running = true
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
      var unitContent = "[Unit]\nDescription=" + (root.unitDescription || baseName) + "\n\n" +
        "[Timer]\nOnCalendar=" + root.onCalendar + "\n" + installSection + "\n"
      createProcess.command = [
        "sh", "-c",
        "mkdir -p '" + targetDir + "' && " +
        "printf '%s' " + JSON.stringify(unitContent) + " > '" + targetDir + "/" + baseName + ".timer'"
      ]
      createProcess.running = true
    }
  }
}