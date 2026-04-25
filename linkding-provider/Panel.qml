import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 560 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

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
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://example.com"
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Title"
                placeholderText: "Bookmark title"
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Tags"
                placeholderText: "dev, tools, notes"
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Description"
                placeholderText: "Optional description"
            }

            NButton {
                text: "Close"
                onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
            }

            NButton {
                text: "Add"
                highlighted: true
            }
        }
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded")
    }
}