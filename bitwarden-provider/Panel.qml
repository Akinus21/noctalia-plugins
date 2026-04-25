import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 400 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property string panelMode: pluginApi?.pluginSettings?._panelMode || "view"
    readonly property var viewItem: pluginApi?.pluginSettings?._viewItem || null
    readonly property var editItem: pluginApi?.pluginSettings?._editItem || null

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

            NLabel {
                text: "Bitwarden Vault"
                font.bold: true
                font.pixelSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NLabel {
                text: panelMode === "setup" ? "Setup Wizard" : "Vault Item"
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