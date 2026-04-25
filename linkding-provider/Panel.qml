import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 300 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginL

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NLabel {
                        label: "New Bookmark"
                    }

                    NTextInput {
                        id: urlInput
                        Layout.fillWidth: true
                        label: "URL"
                        placeholderText: "https://example.com"
                    }

                    NTextInput {
                        id: tagsInput
                        Layout.fillWidth: true
                        label: "Tags"
                        placeholderText: "dev, tools"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NButton {
                            text: "Cancel"
                            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }

                        NButton {
                            text: "Add"
                            highlighted: true
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded")
    }
}