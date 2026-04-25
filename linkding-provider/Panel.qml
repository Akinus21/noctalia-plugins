import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: mainContainer
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 300 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    Item {
        id: mainContainer
        anchors.fill: parent

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            NText {
                text: "Linkding Bookmarks"
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
            }

            NText {
                text: "Configure and manage your Linkding bookmarks"
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
            }

            NTextInput {
                id: urlInput
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://example.com"
            }

            NTextInput {
                id: titleInput
                Layout.fillWidth: true
                label: "Title"
                placeholderText: "Bookmark title"
            }

            NButton {
                text: "Open Settings"
                icon: "settings"
                onClicked: BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest)
            }

            NButton {
                text: "Add"
                highlighted: true
                onClicked: Logger.i("LinkdingPanel", "Add clicked, URL:", urlInput.text)
            }
        }
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded")
    }
}