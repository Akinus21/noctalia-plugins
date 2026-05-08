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

    property bool editEnableDaemon: cfg.enableDaemon ?? defaults.enableDaemon ?? false
    property string editWallpaperPath: cfg.lastWallpaper ?? defaults.lastWallpaper ?? ""

    property string daemonStatus: "stopped"
    property bool akspraypaintInstalled: false

    spacing: Style.marginL

    NFilePicker {
        id: wallpaperPicker
        title: pluginApi?.tr("settings.wallpaper.title") || "Choose a wallpaper"
        selectionMode: "files"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp"]
        showHiddenFiles: false
        allowMultiSelection: false

        function openPicker() {
            openFilePicker()
        }

        onAccepted: {
            if (selectedPaths.length > 0) {
                root.editWallpaperPath = selectedPaths[0]
            }
        }
    }

    // ── Installation status ────────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: installRow.implicitHeight + Style.marginL * 2
        color: Color.mSurface
        radius: Style.radiusM

        RowLayout {
            id: installRow
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            NIcon {
                icon: akspraypaintInstalled ? "check" : "x"
                color: Color.mOnSurface
                pointSize: Style.iconSizeM
            }

            NText {
                text: akspraypaintInstalled
                    ? (pluginApi?.tr("settings.installed") || "AKSprayPaint is installed")
                    : (pluginApi?.tr("settings.notInstalled") || "AKSprayPaint not found — run: brew install akspraypaint")
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            NButton {
                text: akspraypaintInstalled
                    ? (pluginApi?.tr("settings.recheck") || "Recheck")
                    : (pluginApi?.tr("settings.install") || "Install")
                outlined: true
                onClicked: checkInstallation()
            }
        }
    }

    // ── Daemon toggle ──────────────────────────────────────────────────────

    NToggle {
        label: pluginApi?.tr("settings.enableDaemon") || "Enable Daemon"
        description: daemonStatus === "running"
            ? (pluginApi?.tr("settings.daemonRunning") || "Watch daemon is running")
            : (pluginApi?.tr("settings.daemonStopped") || "Watch daemon is stopped")
        checked: root.editEnableDaemon
        onToggled: function(checked) {
            root.editEnableDaemon = checked
            toggleDaemon()
        }
    }

    // ── Wallpaper selection ────────────────────────────────────────────────

    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: wallpaperContent.implicitHeight + Style.marginL * 2
        color: Color.mSurface
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

                        Text {
                            anchors.fill: parent
                            text: pluginApi?.tr("settings.wallpaperPlaceholder") || "No wallpaper selected"
                            color: Color.mOnSurfaceVariant
                            font: wallpaperPathField.font
                            visible: wallpaperPathField.text.length === 0 && !wallpaperPathField.activeFocus
                        }
                    }
                }

                NButton {
                    text: pluginApi?.tr("settings.browse") || "Browse…"
                    outlined: true
                    onClicked: wallpaperPicker.openPicker()
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

    // ── saveSettings ───────────────────────────────────────────────────────

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.enableDaemon = root.editEnableDaemon
        pluginApi.pluginSettings.lastWallpaper = root.editWallpaperPath
        pluginApi.saveSettings()
    }

    // ── Actions ────────────────────────────────────────────────────────────

    Process {
        id: checkProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            root.akspraypaintInstalled = (exitCode === 0)
        }
    }

    Process {
        id: whichProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            root.akspraypaintInstalled = (exitCode === 0)
        }
    }

    Process {
        id: setProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("AKSprayPaintSettings", "Wallpaper set successfully")
            } else {
                Logger.e("AKSprayPaintSettings", "akspraypaint run failed:", exitCode)
            }
        }
    }

    function checkInstallation() {
        whichProcess.command = ["which", "akspraypaint"]
        whichProcess.running = true
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