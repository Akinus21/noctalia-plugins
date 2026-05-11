import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editDefaultScope: cfg.defaultScope ?? defaults.defaultScope ?? "user"
  property int editAutoRefreshSeconds: cfg.autoRefreshSeconds ?? defaults.autoRefreshSeconds ?? 30
  property bool editShowSystemUnits: cfg.showSystemUnits ?? defaults.showSystemUnits ?? false

  property string lingerStatus: ""
  property bool checkingLinger: false

  spacing: Style.marginL

  Component.onCompleted: checkLingerStatus()

  NText {
    text: pluginApi?.tr("settings.defaultScope") || "Default Scope"
    font.weight: Font.Bold
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: "User"
      outlined: root.editDefaultScope !== "system"
      onClicked: root.editDefaultScope = "user"
    }
    NButton {
      text: "System"
      outlined: root.editDefaultScope !== "system"
      onClicked: root.editDefaultScope = "system"
    }

    NText {
      text: root.editDefaultScope === "user"
        ? "Units stored in ~/.config/systemd/user/"
        : "Units stored in /etc/systemd/system/ (requires root)"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.autoRefresh") || "Auto Refresh (seconds)"
    placeholderText: "30"
    text: String(root.editAutoRefreshSeconds)
    onTextChanged: {
      var n = parseInt(text)
      if (!isNaN(n) && n >= 5) root.editAutoRefreshSeconds = n
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NToggle {
      checked: root.editShowSystemUnits
      onToggled: root.editShowSystemUnits = checked
    }

    NText {
      text: pluginApi?.tr("settings.showSystemUnits") || "Show System Units"
      color: Color.mOnSurface
    }
  }

  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: lingerBoxContent.implicitHeight + Style.marginL * 2
    color: Color.mSurfaceContainer
    radius: Style.radiusM

    ColumnLayout {
      id: lingerBoxContent
      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("settings.lingerStatus") || "Linger Status"
          font.weight: Font.Bold
          Layout.fillWidth: true
        }

        NButton {
          text: "Check"
          outlined: true
          onClicked: checkLingerStatus()
        }
      }

      NText {
        text: checkingLinger ? "Checking..." : lingerStatus
        color: checkingLinger ? Color.mOnSurfaceVariant : Color.mOnSurface
        pointSize: Style.fontSizeS
        Layout.fillWidth: true
        wrapMode: Text.Wrap
      }

      NText {
        text: "Linger enabled means user services keep running after you log out. Run: loginctl enable-linger $USER"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        Layout.fillWidth: true
        wrapMode: Text.Wrap
      }
    }
  }

  NText {
    text: "Requires: systemctl (systemd)"
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  function checkLingerStatus() {
    checkingLinger = true
    lingerStatus = ""
    lingerProcess.command = ["loginctl", "show-user", Quickshell.env("USER") || "root"]
    lingerProcess.running = true
  }

  Process {
    id: lingerProcess
    property string out: ""
    environment: Object.assign({}, Qt.application.environment)

    stdout: SplitParser {
      onRead: function(data) { lingerProcess.out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("SystemdSettings", "linger stderr:", data) }
    }
    onExited: function(exitCode, exitStatus) {
      checkingLinger = false
      var lines = lingerProcess.out.split("\n")
      var lingerLine = ""
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].indexOf("Linger") !== -1) {
          lingerLine = lines[i]
          break
        }
      }
      if (lingerLine.indexOf("=yes") !== -1 || lingerLine.indexOf("=1") !== -1) {
        lingerStatus = "Enabled — user services persist after logout"
        pluginApi.pluginSettings.lingerEnabled = true
      } else if (lingerLine) {
        lingerStatus = "Disabled — user services stop on logout"
        pluginApi.pluginSettings.lingerEnabled = false
      } else {
        lingerStatus = "Unknown (could not determine linger status)"
      }
      lingerProcess.out = ""
    }
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.defaultScope = root.editDefaultScope
    pluginApi.pluginSettings.autoRefreshSeconds = root.editAutoRefreshSeconds
    pluginApi.pluginSettings.showSystemUnits = root.editShowSystemUnits
    pluginApi.saveSettings()
    ToastService.showNotice("Settings saved")
  }
}