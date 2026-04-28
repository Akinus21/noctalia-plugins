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

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

    implicitWidth: isVertical ? capsuleHeight : contentWidth
    implicitHeight: isVertical ? contentHeight : capsuleHeight

    readonly property int keybindCount: pluginApi?.pluginSettings?._keybindCount || 0

    contentWidth: rowLayout.implicitWidth + Style.marginS * 2
    contentHeight: rowLayout.implicitHeight + Style.marginS * 2

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Style.marginS

        NIcon {
            name: "keyboard"
            isTablerIcon: true
            width: Style.iconSizeS
            height: Style.iconSizeS
        }

        NLabel {
            text: keybindCount > 0 ? String(keybindCount) : ""
            font.pixelSize: Style.fontSizeS
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.open"), "action": "open", "icon": "keyboard" },
            { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
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