import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root
    property var pluginApi: null

    property string akspraypaintPath: pluginApi?.pluginSettings?.akspraypaintPath || "akspraypaint"
    property bool isInstalled: false
    property bool daemonRunning: false

    Process {
        id: checkProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            isInstalled = (exitCode === 0)
            if (!isInstalled) {
                Logger.w("AKSprayPaintMain", "akspraypaint not found at:", akspraypaintPath)
            } else {
                Logger.i("AKSprayPaintMain", "akspraypaint found at:", akspraypaintPath)
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
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
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
        checkProcess.command = ["sh", "-c", "test -x " + akspraypaintPath + " && " + akspraypaintPath + " --version"]
        checkProcess.running = true
    }

    function startDaemon() {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot start daemon: akspraypaint not installed")
            return
        }
        daemonProcess.command = ["sh", "-c", akspraypaintPath + " watch"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Daemon started")
    }

    function stopDaemon() {
        disableProcess.command = ["sh", "-c", akspraypaintPath + " --disable"]
        disableProcess.running = true
        daemonRunning = false
        Logger.i("AKSprayPaintMain", "Daemon stop requested")
    }

    function runWallpaper(wallpaperPath) {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot run: akspraypaint not installed")
            return
        }
        runProcess.command = ["sh", "-c", akspraypaintPath + " run --wallpaper " + wallpaperPath]
        runProcess.running = true
        Logger.i("AKSprayPaintMain", "Running with wallpaper:", wallpaperPath)
    }

    Component.onCompleted: {
        checkInstalled()
        if (pluginApi?.pluginSettings?.enableDaemon) {
            Qt.callLater(startDaemon)
        }
    }
}