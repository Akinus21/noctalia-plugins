import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root
    property var pluginApi: null

    property bool isInstalled: false
    property bool daemonRunning: false

    Process {
        id: checkProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            isInstalled = (exitCode === 0)
            if (!isInstalled) {
                Logger.w("AKSprayPaintMain", "akspraypaint not found in PATH")
            } else {
                Logger.i("AKSprayPaintMain", "akspraypaint found")
            }
        }
    }

    Process {
        id: daemonProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            daemonRunning = false
        }
    }

    Process {
        id: runProcess
        stdout: SplitParser { onRead: function(d) { Logger.d("AKSprayPaintMain", "run stdout:", d) } }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "run stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("AKSprayPaintMain", "Wallpaper set successfully")
            } else {
                Logger.e("AKSprayPaintMain", "akspraypaint run failed:", exitCode)
            }
        }
    }

    Process {
        id: disableProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            daemonRunning = false
            Logger.i("AKSprayPaintMain", "Daemon stopped")
        }
    }

    function checkInstalled() {
        checkProcess.command = ["which", "akspraypaint"]
        checkProcess.running = true
    }

    function startDaemon() {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot start daemon: akspraypaint not installed")
            return
        }
        daemonProcess.command = ["sh", "-c", "akspraypaint watch"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Daemon started")
    }

    function stopDaemon() {
        disableProcess.command = ["sh", "-c", "akspraypaint --disable"]
        disableProcess.running = true
        daemonRunning = false
        Logger.i("AKSprayPaintMain", "Daemon stop requested")
    }

    function runWallpaper(wallpaperPath) {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot run: akspraypaint not installed")
            return
        }
        var cmd = "WAYLAND_DISPLAY=" + (Qt.envVar("WAYLAND_DISPLAY") || "") + " XDG_RUNTIME_DIR=" + (Qt.envVar("XDG_RUNTIME_DIR") || "/run/user/1000") + " akspraypaint run --wallpaper '" + wallpaperPath + "'"
        runProcess.command = ["sh", "-c", cmd]
        runProcess.running = true
        Logger.i("AKSprayPaintMain", "Running with wallpaper:", wallpaperPath)
    }

    Component.onCompleted: {
        checkInstalled()
        var lastWallpaper = pluginApi?.pluginSettings?.lastWallpaper
        if (pluginApi?.pluginSettings?.enableDaemon && lastWallpaper) {
            runWallpaper(lastWallpaper)
            Qt.callLater(startDaemon)
        } else if (pluginApi?.pluginSettings?.enableDaemon) {
            Qt.callLater(startDaemon)
        }
    }
}