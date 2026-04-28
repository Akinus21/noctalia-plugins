import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

    implicitWidth: isVertical ? capsuleHeight : keyboardIcon.width + Style.marginS * 2
    implicitHeight: isVertical ? keyboardIcon.height + Style.marginS * 2 : capsuleHeight

    NText {
        id: keyboardIcon
        anchors.centerIn: parent
        text: "[K]"
        pointSize: Style.fontSizeS
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": "Open Keybinds", "action": "open" },
            { "label": "Settings", "action": "settings" }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if (action === "open") {
                pluginApi.openPanel(screen, root)
            } else if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                pluginApi.togglePanel(screen, root)
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            }
        }
    }
}