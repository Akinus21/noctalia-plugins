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
    property real contentPreferredHeight: 500 * Style.uiScaleRatio
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

            NBox {
                id: formBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: formColumn.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: formColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

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

                    NTextInput {
                        id: tagsInput
                        Layout.fillWidth: true
                        label: "Tags"
                        placeholderText: "dev, tools, notes"
                    }

                    NTextInput {
                        id: descInput
                        Layout.fillWidth: true
                        label: "Description"
                        placeholderText: "Optional description"
                    }

                    Item { Layout.fillHeight: true }
                }
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