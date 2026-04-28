import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var launcher: null

    property string name: "Niri Keybinds"
    property string supportedLayouts: "list"
    property bool handleSearch: false
    property bool supportsAutoPaste: false

    property bool showsCategories: false
    property string selectedCategory: "all"
    property var categories: ["all"]
    property var categoryIcons: ({ "all": "keyboard" })

    function init() {
        Logger.i("NiriKeybinds", "Initializing")
    }

    function onOpened() {
        if (pluginApi?.mainInstance) {
            pluginApi.mainInstance.loadKeybinds()
        }
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">niri") || searchText.startsWith(">keybinds")
    }

    function commands() {
        return [
            {
                "name": ">niri keybinds",
                "description": "Open Niri keybinds panel",
                "icon": "keyboard",
                "isTablerIcon": true,
                "onActivate": function() { openPanel() }
            },
            {
                "name": ">keybinds",
                "description": "Open Niri keybinds panel",
                "icon": "keyboard",
                "isTablerIcon": true,
                "onActivate": function() { openPanel() }
            },
            {
                "name": ">niri reload",
                "description": "Reload keybinds from config",
                "icon": "refresh",
                "isTablerIcon": true,
                "onActivate": function() { reloadKeybinds() }
            },
            {
                "name": ">niri save",
                "description": "Save keybinds to config",
                "icon": "save",
                "isTablerIcon": true,
                "onActivate": function() { saveKeybinds() }
            }
        ]
    }

    function getResults(searchText) {
        return []
    }

    function openPanel() {
        if (!pluginApi) return
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.openPanel(screen)
        })
        launcher.close()
    }

    function reloadKeybinds() {
        if (pluginApi?.mainInstance) {
            pluginApi.mainInstance.loadKeybinds()
            ToastService.showNotice("Keybinds reloaded")
        }
        launcher.close()
    }

    function saveKeybinds() {
        if (pluginApi?.mainInstance) {
            pluginApi.mainInstance.saveKeybinds()
            ToastService.showNotice("Keybinds saved")
        }
        launcher.close()
    }
}