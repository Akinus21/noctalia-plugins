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
    property real contentPreferredHeight: 600 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property bool isEditMode: false
    readonly property var editBookmark: null

    Component.onCompleted: {
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

            NText {
                text: "Bitwarden Vault"
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
            }

            NLabel {
                text: "Vault Item"
                Layout.fillWidth: true
            }

            NButton {
                text: "Close"
                outlined: true
                Layout.fillWidth: true
                onClicked: closePanel()
            }
        }
    }

    function closePanel() {
        pluginApi.pluginSettings._panelMode = "view"
        pluginApi.pluginSettings._viewItem = null
        pluginApi.pluginSettings._editItem = null
        pluginApi.saveSettings()
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }
}