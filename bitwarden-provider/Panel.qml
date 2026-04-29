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
    property real contentPreferredHeight: 500 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    property string panelMode: "view"
    property var viewItem: null

    Component.onCompleted: {
        if (pluginApi && pluginApi.pluginSettings) {
            panelMode = pluginApi.pluginSettings._panelMode || "view"
            viewItem = pluginApi.pluginSettings._viewItem || null
        }
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
                text: viewItem ? (viewItem.name || "Vault Item") : "Vault Item"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NText {
                text: "Username"
                font.weight: Font.Bold
            }

            NText {
                text: viewItem && viewItem.login ? (viewItem.login.username || "-") : "-"
                Layout.fillWidth: true
            }

            NButton {
                text: "Copy Username"
                outlined: true
                Layout.fillWidth: true
                visible: viewItem && viewItem.login && viewItem.login.username
                onClicked: {
                    copyToClipboard(viewItem.login.username)
                    ToastService.showNotice("Username copied")
                }
            }

            NText {
                text: "Password"
                font.weight: Font.Bold
            }

            NText {
                text: viewItem && viewItem.login && viewItem.login.password ? "********" : "-"
                Layout.fillWidth: true
            }

            NButton {
                text: "Copy Password"
                outlined: true
                Layout.fillWidth: true
                visible: viewItem && viewItem.login && viewItem.login.password
                onClicked: {
                    copyToClipboard(viewItem.login.password)
                    ToastService.showNotice("Password copied")
                }
            }

            NText {
                text: "URL"
                font.weight: Font.Bold
            }

            NText {
                text: viewItem && viewItem.login ? (viewItem.login.uri || "-") : "-"
                color: Color.mPrimary
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

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
        pluginApi.saveSettings()
        if (pluginApi.panelOpenScreen && pluginApi.togglePanel) {
            pluginApi.togglePanel(pluginApi.panelOpenScreen)
        }
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + String(text).replace(/'/g, "'\\''") + "' | wl-copy"])
    }
}
