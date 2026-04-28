import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 500 * Style.uiScaleRatio
    property real contentPreferredHeight: 600 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "red"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NLabel {
            text: "Niri Keybinds Panel"
            font.bold: true
            font.pixelSize: Style.fontSizeL
            Layout.fillWidth: true
        }

        NLabel {
            text: "Test panel - if you see this, QML works"
            Layout.fillWidth: true
        }
    }
}