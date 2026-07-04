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
  property var editEnabledRemotes: cfg.enabledRemotes ?? defaults.enabledRemotes ?? ["flathub", "flathub-beta"]

  spacing: Style.marginL

  NText {
    text: pluginApi?.tr("settings.defaultScope") || "Default Scope"
    font.weight: Font.Bold
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      text: pluginApi?.tr("settings.scopeUser") || "User"
      outlined: root.editDefaultScope !== "system"
      onClicked: root.editDefaultScope = "user"
    }
    NButton {
      text: pluginApi?.tr("settings.scopeSystem") || "System"
      outlined: root.editDefaultScope !== "system"
      onClicked: root.editDefaultScope = "system"
    }

    NText {
      text: root.editDefaultScope === "user"
        ? (pluginApi?.tr("settings.scopeUserDesc") || "Flatpaks installed for current user only")
        : (pluginApi?.tr("settings.scopeSystemDesc") || "System-wide flatpak installations")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }
  }

  NText {
    text: pluginApi?.tr("settings.manageRemotes") || "Manage Remotes"
    font.weight: Font.Bold
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }

  NText {
    text: pluginApi?.tr("settings.enabledRemotes") || "Enabled Remotes"
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeXS
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: "Flathub"
        outlined: !isRemoteEnabled("flathub")
        onClicked: toggleRemote("flathub")
      }
      NButton {
        text: "Flathub Beta"
        outlined: !isRemoteEnabled("flathub-beta")
        onClicked: toggleRemote("flathub-beta")
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: "GNOME Nightly"
        outlined: !isRemoteEnabled("gnome-nightly")
        onClicked: toggleRemote("gnome-nightly")
      }
      NButton {
        text: "GNOME Stable"
        outlined: !isRemoteEnabled("gnome")
        onClicked: toggleRemote("gnome")
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: "KDE"
        outlined: !isRemoteEnabled("kde")
        onClicked: toggleRemote("kde")
      }
      NButton {
        text: "KDE Next"
        outlined: !isRemoteEnabled("kde-next")
        onClicked: toggleRemote("kde-next")
      }
    }
  }

  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: infoBoxContent.implicitHeight + Style.marginL * 2
    color: Color.mSurfaceContainer
    radius: Style.radiusM

    ColumnLayout {
      id: infoBoxContent
      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginS

      NText {
        text: "About Flatpak Scopes"
        font.weight: Font.Bold
        Layout.fillWidth: true
      }

      NText {
        text: "User scope: Flatpaks are installed in ~/.var/app/ and only accessible to your user account."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        Layout.fillWidth: true
        wrapMode: Text.Wrap
      }

      NText {
        text: "System scope: Flatpaks are installed in /var/lib/flatpak/ and accessible to all users (requires root)."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeXS
        Layout.fillWidth: true
        wrapMode: Text.Wrap
      }
    }
  }

  NText {
    text: "Requires: flatpak"
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  function isRemoteEnabled(remoteName) {
    return root.editEnabledRemotes.indexOf(remoteName) !== -1
  }

  function toggleRemote(remoteName) {
    var idx = root.editEnabledRemotes.indexOf(remoteName)
    if (idx !== -1) {
      root.editEnabledRemotes.splice(idx, 1)
    } else {
      root.editEnabledRemotes.push(remoteName)
    }
    root.editEnabledRemotes = root.editEnabledRemotes.slice()
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.defaultScope = root.editDefaultScope
    pluginApi.pluginSettings.enabledRemotes = root.editEnabledRemotes.slice()
    pluginApi.saveSettings()
    ToastService.showNotice("Settings saved")
  }
}
