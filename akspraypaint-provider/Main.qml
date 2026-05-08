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
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "daemon stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            Logger.w("AKSprayPaintMain", "daemonProcess exited, keeping daemonRunning=true (background fork)")
            // Don't set daemonRunning = false here - akspraypaint watch forks to background
        }
    }

    Process {
        id: runProcess
        stdout: SplitParser { onRead: function(d) { Logger.d("AKSprayPaintMain", "run stdout:", d) } }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "run stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            Logger.i("AKSprayPaintMain", "runProcess exited code=" + exitCode)
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
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "disable stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            daemonRunning = false
            Logger.i("AKSprayPaintMain", "Daemon stopped")
        }
    }

    function checkInstalled() {
        var env = Object.assign({}, Qt.application.environment)
        checkProcess.environment = env
        checkProcess.command = ["sh", "-c", "which akspraypaint"]
        checkProcess.running = true
    }

    function startDaemon() {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot start daemon: akspraypaint not installed")
            return
        }
        if (daemonProcess.running) {
            Logger.w("AKSprayPaintMain", "daemonProcess busy")
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        daemonProcess.environment = env
        daemonProcess.command = ["sh", "-c", "akspraypaint watch"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Daemon started")
    }

    function stopDaemon() {
        if (disableProcess.running) {
            Logger.w("AKSprayPaintMain", "disableProcess busy")
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        disableProcess.environment = env
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
        if (runProcess.running) {
            Logger.w("AKSprayPaintMain", "runProcess busy, waiting...")
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        runProcess.environment = env
        runProcess.command = ["sh", "-c", "akspraypaint run --wallpaper '" + wallpaperPath + "'"]
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