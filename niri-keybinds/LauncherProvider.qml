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
        if (launcher) launcher.close()
    }
}