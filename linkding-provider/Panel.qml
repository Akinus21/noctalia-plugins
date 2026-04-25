import QtQuick
import QtQuick.Layouts
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

    Component.onDestruction: {
        Logger.i("LinkdingPanel", "Panel destroyed")
    }

    onPluginApiChanged: {
        Logger.i("LinkdingPanel", "pluginApi changed:", pluginApi !== null)
    }

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
        Logger.i("LinkdingPanel", "Panel loaded, pluginApi:", pluginApi !== null)
    }
}