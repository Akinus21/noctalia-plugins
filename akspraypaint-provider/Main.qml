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
        stdout: SplitParser { onRead: function(d) { checkOut += d } }
        stderr: SplitParser { onRead: function(d) { Logger.w("AKSprayPaintMain", "check stderr:", d) } }
        onExited: function(exitCode, exitStatus) {
            var foundPath = checkOut.trim()
            isInstalled = (foundPath.length > 0)
            if (!isInstalled) {
                Logger.w("AKSprayPaintMain", "akspraypaint not found, tried linuxbrew and PATH")
            } else {
                Logger.i("AKSprayPaintMain", "akspraypaint found at:", foundPath, "cleaning cache...")
                Qt.callLater(cleanCache)
            }
            checkOut = ""
        }
    }

    property string checkOut: ""

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
        interval: 100
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
        checkProcess.command = ["sh", "-c",
            "[ -x /home/linuxbrew/.linuxbrew/bin/akspraypaint ] && echo /home/linuxbrew/.linuxbrew/bin/akspraypaint && exit 0; " +
            "command -v akspraypaint 2>/dev/null || " +
            "which akspraypaint 2>/dev/null || " +
            "type akspraypaint 2>/dev/null || " +
            "echo ''"]
        checkProcess.running = true
    }

    function startDaemonWithWallpaper(wallpaperPath) {
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
        daemonProcess.command = ["sh", "-c",
            "AKSP='/home/linuxbrew/.linuxbrew/bin/akspraypaint'; " +
            "COMMAND=$(command -v akspraypaint 2>/dev/null || [ -x \"$AKSP\" ] && echo \"$AKSP\" || echo ''); " +
            "[ -z \"$COMMAND\" ] && exit 1; " +
            "$COMMAND watch --wallpaper '" + wallpaperPath + "'"]
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

    function stopDaemon(wallpaperPath) {
        _pendingWallpaperRestart = true
        _pendingWallpaperPath = wallpaperPath || ""
        if (disableProcess.running) {
            Logger.w("AKSprayPaintMain", "stopDaemon: disableProcess busy, pending wallpaper:", _pendingWallpaperPath)
            return
        }
        var env = Object.assign({}, Qt.application.environment)
        disableProcess.environment = env
        disableProcess.command = ["sh", "-c", "PID=$(cat ~/.cache/akspraypaint/watch.pid 2>/dev/null) && [ -n \"$PID\" ] && kill $PID 2>/dev/null && rm -f ~/.cache/akspraypaint/watch.pid"]
        disableProcess.running = true
        daemonRunning = false
        Logger.i("AKSprayPaintMain", "Daemon stop requested via PID file")
    }

    function runWallpaperOnce(wallpaperPath) {
        if (runProcess.running) {
            Logger.w("AKSprayPaintMain", "runWallpaperOnce: runProcess busy")
            return
        }
        activeWallpaperPath = wallpaperPath
        wallpaperBusy = true
        var env = Object.assign({}, Qt.application.environment)
        runProcess.environment = env
        runProcess.command = ["sh", "-c",
            "AKSP='/home/linuxbrew/.linuxbrew/bin/akspraypaint'; " +
            "COMMAND=$(command -v akspraypaint 2>/dev/null || [ -x \"$AKSP\" ] && echo \"$AKSP\" || echo ''); " +
            "[ -z \"$COMMAND\" ] && exit 1; " +
            "$COMMAND run --wallpaper '" + wallpaperPath + "' --no-cache"]
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