import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property bool editEnableDaemon: cfg.enableDaemon ?? defaults.enableDaemon ?? false
    property string editWallpaperPath: cfg.lastWallpaper ?? defaults.lastWallpaper ?? ""
    property string akspraypaintPath: cfg.akspraypaintPath ?? defaults.akspraypaintPath ?? "/home/linuxbrew/.linuxbrew/bin/akspraypaint"

    property string installStatus: "checking"
    property string daemonStatus: "stopped"
    property bool akspraypaintInstalled: false

    spacing: Style.marginL

    FileDialog {
        id: wallpaperDialog
        title: pluginApi?.tr("settings.wallpaper.title") || "Choose a wallpaper"
        folder: "/var/home/gabriel"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.avif *.bmp)", "All files (*)"]
        onAccepted: {
            var path = wallpaperDialog.fileUrl.toString().replace("file://", "")
            root.editWallpaperPath = path
        }
    }

    // ── AKSprayPaint path ──────────────────────────────────────────────────

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.akspraypaintPath.label") || "AKSprayPaint Path"
        placeholderText: "/home/linuxbrew/.linuxbrew/bin/akspraypaint"
        text: root.akspraypaintPath
        onTextChanged: root.akspraypaintPath = text
    }

    // ── Installation status ────────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: installRow.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceContainer
        radius: Style.radiusM

        RowLayout {
            id: installRow
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            NIcon {
                icon: root.akspraypaintInstalled ? "check-circle" : "x-circle"
                color: root.akspraypaintInstalled ? "#4CAF50" : "#F44336"
                pointSize: Style.iconSizeM
            }

            NText {
                text: root.akspraypaintInstalled
                    ? (pluginApi?.tr("settings.installed") || "AKSprayPaint is installed")
                    : (pluginApi?.tr("settings.notInstalled") || "AKSprayPaint not found")
                color: root.akspraypaintInstalled ? "#4CAF50" : "#F44336"
                Layout.fillWidth: true
            }

            NButton {
                text: pluginApi?.tr("settings.checkInstall") || "Check"
                outlined: true
                onClicked: checkInstallation()
            }
        }
    }

    // ── Daemon toggle ──────────────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: daemonContent.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceContainer
        radius: Style.radiusM

        ColumnLayout {
            id: daemonContent
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS

                NText {
                    text: pluginApi?.tr("settings.enableDaemon") || "Enable Daemon"
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                NButton {
                    text: editEnableDaemon
                        ? (pluginApi?.tr("settings.daemonOn") || "ON")
                        : (pluginApi?.tr("settings.daemonOff") || "OFF")
                    outlined: !editEnableDaemon
                    onClicked: {
                        editEnableDaemon = !editEnableDaemon
                        toggleDaemon()
                    }
                }
            }

            NText {
                text: daemonStatus === "running"
                    ? (pluginApi?.tr("settings.daemonRunning") || "Daemon is running")
                    : (pluginApi?.tr("settings.daemonStopped") || "Daemon is stopped")
                color: daemonStatus === "running" ? "#4CAF50" : Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }

    // ── Wallpaper selection ────────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: wallpaperContent.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceContainer
        radius: Style.radiusM

        ColumnLayout {
            id: wallpaperContent
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginS

            NText {
                text: pluginApi?.tr("settings.wallpaper") || "Wallpaper"
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Style.marginS
                Layout.fillWidth: true

                NBox {
                    Layout.fillWidth: true
                    implicitHeight: wallpaperPathField.implicitHeight + Style.marginM * 2
                    color: Color.mSurface
                    radius: Style.radiusM

                    TextInput {
                        id: wallpaperPathField
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginM }
                        text: root.editWallpaperPath
                        color: Color.mOnSurface
                        font.pixelSize: 14
                        onTextChanged: root.editWallpaperPath = text
                        placeholderText: pluginApi?.tr("settings.wallpaperPlaceholder") || "No wallpaper selected"
                    }
                }

                NButton {
                    text: pluginApi?.tr("settings.browse") || "Browse…"
                    outlined: true
                    onClicked: wallpaperDialog.open()
                }
            }
        }
    }

    // ── Set button ─────────────────────────────────────────────────────────

    NButton {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.set") || "Set"
        enabled: root.akspraypaintInstalled && root.editWallpaperPath !== ""
        onClicked: setWallpaper()
    }

    // ── Process for checking install ───────────────────────────────────────

    Process {
        id: checkProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            root.akspraypaintInstalled = (exitCode === 0)
            root.installStatus = root.akspraypaintInstalled ? "installed" : "notInstalled"
            if (root.akspraypaintInstalled) {
                checkDaemonStatus()
            }
        }
    }

    Process {
        id: daemonCheckProcess
        stdout: SplitParser { onRead: function(data) { } }
        stderr: SplitParser { onRead: function(data) { } }
        onExited: function(exitCode, exitStatus) {
            root.daemonStatus = "stopped"
        }
    }

    Process {
        id: setProcess
        stdout: SplitParser { onRead: function(data) { } }
        stderr: SplitParser { onRead: function(data) { } }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("AKSprayPaintSettings", "Wallpaper set successfully")
            } else {
                Logger.e("AKSprayPaintSettings", "Failed to set wallpaper:", exitCode)
            }
        }
    }

    // ── saveSettings ───────────────────────────────────────────────────────

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.akspraypaintPath = root.akspraypaintPath
        pluginApi.pluginSettings.enableDaemon = root.editEnableDaemon
        pluginApi.pluginSettings.lastWallpaper = root.editWallpaperPath
        pluginApi.saveSettings()
    }

    // ── Actions ────────────────────────────────────────────────────────────

    function checkInstallation() {
        checkProcess.command = [root.akspraypaintPath, "--version"]
        checkProcess.running = true
    }

    function checkDaemonStatus() {
        var home = Qt.envVar("HOME") || "/root"
        daemonCheckProcess.command = ["sh", "-c", "test -f '" + home + "/.cache/akspraypaint/watch.pid' && kill -0 $(cat '" + home + "/.cache/akspraypaint/watch.pid") 2>/dev/null && echo 'running' || echo 'stopped'"]
        daemonCheckProcess.running = true
    }

    function toggleDaemon() {
        var main = pluginApi?.mainInstance
        if (!main) return
        if (editEnableDaemon) {
            main.startDaemon()
            daemonStatus = "running"
        } else {
            main.stopDaemon()
            daemonStatus = "stopped"
        }
        saveSettings()
    }

    function setWallpaper() {
        if (!root.editWallpaperPath) return
        var main = pluginApi?.mainInstance
        if (!main) return
        main.runWallpaper(root.editWallpaperPath)
        if (editEnableDaemon) {
            Qt.callLater(function() {
                main.startDaemon()
                daemonStatus = "running"
            })
        }
        saveSettings()
    }

    Component.onCompleted: {
        checkInstallation()
    }
}