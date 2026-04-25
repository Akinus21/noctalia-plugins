import QtQuick 2.15
import QtQuick.Layouts 2.15
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 400 * Style.uiScaleRatio
    property real contentPreferredHeight: 300 * Style.uiScaleRatio

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

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Style.marginL
                    }
                    spacing: Style.marginL

                    NLabel {
                        id: titleLabel
                        label: "New Bookmark"
                        Layout.alignment: Qt.AlignHCenter
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
                            id: cancelButton
                            text: "Cancel"
                            onClicked: root.pluginApi?.closePanel(root.pluginApi?.panelOpenScreen)
                        }

                        Item { Layout.fillWidth: true }

                        NButton {
                            id: addButton
                            text: "Add"
                            highlighted: true
                            enabled: urlInput.text.trim().length > 0
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel component completed")
    }
}