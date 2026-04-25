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

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Color.mSurface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginL

            NLabel {
                label: "New Bookmark"
                description: "Add a new Linkding bookmark"
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

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded")
    }
}