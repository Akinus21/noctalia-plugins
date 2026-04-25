import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    focus: true

    property var pluginApi: null
    readonly property var geometryPlaceholder: mainContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 380 * Style.uiScaleRatio
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

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: "bookmark-plus"
                    pointSize: Style.fontSizeXL
                    color: Color.mPrimary
                }

                NText {
                    text: "Add Bookmark"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    baseSize: Style.baseWidgetSize
                    onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                }
            }

            // Form
            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

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
                        placeholderText: "dev, tools"
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Cancel"
                    onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Add"
                    highlighted: true
                }
            }
        }
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded")
    }
}