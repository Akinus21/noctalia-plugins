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
                Logger.i("AKSprayPaintMain", "akspraypaint found, cleaning cache...")
                Qt.callLater(cleanCache)
            }
        }
    }

    Process {
        id: cleanProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) {} }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("AKSprayPaintMain", "Cache clean done, updating...")
            } else {
                Logger.w("AKSprayPaintMain", "Cache clean failed:", exitCode)
            }
            Qt.callLater(runBrewUpdate)
        }
    }

    Process {
        id: updateProcess
        stdout: SplitParser { onRead: function(d) { Logger.d("AKSprayPaintMain", "update stdout:", d) } }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "update stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                Logger.i("AKSprayPaintMain", "Brew update done, waiting before daemon start...")
            } else {
                Logger.w("AKSprayPaintMain", "Brew update exited with code:", exitCode)
            }
            updateDelayTimer.start()
        }
    }

    Timer {
        id: updateDelayTimer
        interval: 5000
        onTriggered: function() {
            Qt.callLater(startInitDaemon)
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
                Qt.callLater(function() { startDaemonWithWallpaper(wp) })
            }
        }
    }

    Process {
        id: daemonProcess
        stdout: SplitParser { onRead: function(d) {} }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "daemon stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            Logger.w("AKSprayPaintMain", "daemonProcess exited (fork completed), resetting running flag")
            daemonProcess.running = false
        }
    }

    function cleanCache() {
        var env = Object.assign({}, Qt.application.environment)
        cleanProcess.environment = env
        cleanProcess.command = ["sh", "-c", "akspraypaint clean"]
        cleanProcess.running = true
    }

    function runBrewUpdate() {
        var env = Object.assign({}, Qt.application.environment)
        updateProcess.environment = env
        updateProcess.command = ["sh", "-c", "brew update && brew upgrade akspraypaint"]
        updateProcess.running = true
    }

    function startInitDaemon() {
        if (!pluginApi) return
        var enabled = pluginApi.pluginSettings?.enableDaemon
        var wallpaper = pluginApi.pluginSettings?.lastWallpaper
        Logger.i("AKSprayPaintMain", "startInitDaemon: enabled=" + enabled + " wallpaper=" + wallpaper)
        if (enabled && wallpaper) {
            startDaemonWithWallpaper(wallpaper)
        }
    }

    function checkInstalled() {
        var env = Object.assign({}, Qt.application.environment)
        checkProcess.environment = env
        checkProcess.command = ["sh", "-c", "which akspraypaint"]
        checkProcess.running = true
    }

    function startDaemonWithWallpaper(wallpaperPath) {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot start daemon: akspraypaint not installed")
            return
        }
        if (daemonProcess.running) {
            Logger.w("AKSprayPaintMain", "daemonProcess busy")
            return
        }
        if (!wallpaperPath) {
            Logger.w("AKSprayPaintMain", "startDaemonWithWallpaper: no wallpaper path")
            return
        }
        activeWallpaperPath = wallpaperPath
        var env = Object.assign({}, Qt.application.environment)
        daemonProcess.environment = env
        daemonProcess.command = ["sh", "-c", "akspraypaint watch --wallpaper '" + wallpaperPath + "'"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Daemon started with wallpaper:", wallpaperPath)
    }

    function startDaemon() {
        if (!activeWallpaperPath) {
            Logger.w("AKSprayPaintMain", "startDaemon: no active wallpaper path")
            return
        }
        startDaemonWithWallpaper(activeWallpaperPath)
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

    function startWatchDaemon(wallpaperPath) {
        if (!isInstalled) {
            Logger.w("AKSprayPaintMain", "Cannot start watch: akspraypaint not installed")
            return
        }
        if (daemonProcess.running) {
            Logger.w("AKSprayPaintMain", "daemonProcess busy")
            return
        }
        if (!wallpaperPath) {
            Logger.w("AKSprayPaintMain", "startWatchDaemon: no wallpaper path")
            return
        }
        activeWallpaperPath = wallpaperPath
        var env = Object.assign({}, Qt.application.environment)
        daemonProcess.environment = env
        daemonProcess.command = ["sh", "-c", "akspraypaint watch --wallpaper '" + wallpaperPath + "'"]
        daemonProcess.running = true
        daemonRunning = true
        Logger.i("AKSprayPaintMain", "Watch daemon started with wallpaper:", wallpaperPath)
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

    function runWallpaperOnce(wallpaperPath) {
        if (!isInstalled) return
        if (runProcess.running) {
            Logger.w("AKSprayPaintMain", "runWallpaperOnce: runProcess busy")
            return
        }
        activeWallpaperPath = wallpaperPath
        wallpaperBusy = true
        var env = Object.assign({}, Qt.application.environment)
        runProcess.environment = env
        runProcess.command = ["sh", "-c", "akspraypaint run --wallpaper '" + wallpaperPath + "' --no-cache"]
        runProcess.running = true
        Logger.i("AKSprayPaintMain", "runWallpaperOnce:", wallpaperPath)
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
        }
    }

    Component.onCompleted: {
        checkInstalled()
    }
}