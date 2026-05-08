import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root
    property var pluginApi: null

    property bool isInstalled: false
    property bool daemonRunning: false
    property bool wallpaperBusy: false
    property string currentWallpaperPath: ""
    property string activeWallpaperPath: ""

    property bool _pendingWallpaperRestart: false
    property string _pendingWallpaperPath: ""

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
                Qt.callLater(afterCheck)
            }
        }
    }

    Process {
        id: disableProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "disable stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            daemonRunning = false
            Logger.i("AKSprayPaintMain", "disableProcess exited, pendingRestart=" + _pendingWallpaperRestart)
            if (_pendingWallpaperRestart && _pendingWallpaperPath) {
                _pendingWallpaperRestart = false
                var wp = _pendingWallpaperPath
                _pendingWallpaperPath = ""
                Qt.callLater(function() { runWallpaperInternal(wp) })
            }
        }
    }

    Process {
        id: runProcess
        stdout: SplitParser { onRead: function(d) { Logger.d("AKSprayPaintMain", "run stdout:", d) } }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "run stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            wallpaperBusy = false
            Logger.i("AKSprayPaintMain", "runProcess exited code=" + exitCode)
            if (exitCode === 0) {
                Logger.i("AKSprayPaintMain", "Wallpaper set successfully")
            } else {
                Logger.e("AKSprayPaintMain", "akspraypaint run failed:", exitCode)
            }
            if (_pendingWallpaperRestart && exitCode === 0) {
                _pendingWallpaperRestart = false
                Qt.callLater(function() { startDaemon() })
            }
        }
    }

    Process {
        id: daemonProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "daemon stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            Logger.w("AKSprayPaintMain", "daemonProcess exited (fork completed), resetting running flag")
            // Reset running so subsequent daemon commands work - the background fork keeps running
            daemonProcess.running = false
        }
    }

    function afterCheck() {
        if (!pluginApi) return
        var enabled = pluginApi.pluginSettings?.enableDaemon
        var wallpaper = pluginApi.pluginSettings?.lastWallpaper
        Logger.i("AKSprayPaintMain", "afterCheck: enabled=" + enabled + " wallpaper=" + wallpaper)
        if (enabled && wallpaper) {
            Qt.callLater(function() { initDaemon(wallpaper) })
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
        if (!activeWallpaperPath) {
            Logger.w("AKSprayPaintMain", "startDaemon: no active wallpaper path")
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        daemonProcess.environment = env
        daemonProcess.command = ["sh", "-c", "akspraypaint watch --wallpaper '" + activeWallpaperPath + "'"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Daemon started with wallpaper:", activeWallpaperPath)
    }

    function stopDaemon() {
        if (disableProcess.running) {
            Logger.w("AKSprayPaintMain", "stopDaemon: disableProcess busy")
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        disableProcess.environment = env
        disableProcess.command = ["sh", "-c", "akspraypaint --disable"]
        disableProcess.running = true
        daemonRunning = false
        Logger.i("AKSprayPaintMain", "Daemon stop requested")
    }

    function initDaemon(wallpaperPath) {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "initDaemon: akspraypaint not installed")
            return
        }
        if (!wallpaperPath) {
            Logger.w("AKSprayPaintMain", "initDaemon: no wallpaper path")
            return
        }
        Logger.i("AKSprayPaintMain", "initDaemon: starting with", wallpaperPath)
        _pendingWallpaperRestart = true
        _pendingWallpaperPath = wallpaperPath
        runWallpaperInternal(wallpaperPath)
    }

    function restartDaemonWithWallpaper(wallpaperPath) {
        if (disableProcess.running || daemonProcess.running) {
            Logger.w("AKSprayPaintMain", "restartDaemonWithWallpaper: processes busy")
            return
        }
        _pendingWallpaperRestart = true
        _pendingWallpaperPath = wallpaperPath
        var env = Object.assign({}, Qt.application.environment)
        disableProcess.environment = env
        disableProcess.command = ["sh", "-c", "akspraypaint --disable"]
        disableProcess.running = true
        Logger.i("AKSprayPaintMain", "restartDaemonWithWallpaper: stopping daemon first")
    }

    function runWallpaperInternal(wallpaperPath) {
        if (runProcess.running) {
            Logger.w("AKSprayPaintMain", "runWallpaperInternal: runProcess busy")
            return
        }
        currentWallpaperPath = wallpaperPath
        activeWallpaperPath = wallpaperPath
        wallpaperBusy = true
        var env = Object.assign({}, Qt.application.environment)
        runProcess.environment = env
        runProcess.command = ["sh", "-c", "akspraypaint run --wallpaper '" + wallpaperPath + "'"]
        runProcess.running = true
        Logger.i("AKSprayPaintMain", "runWallpaperInternal:", wallpaperPath)
    }

    function runWallpaper(wallpaperPath) {
        runWallpaperInternal(wallpaperPath)
    }

    Component.onCompleted: {
        checkInstalled()
    }
}