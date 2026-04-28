import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    property var keybinds: []
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""

    Component.onCompleted: {
        if (pluginApi?.mainInstance) {
            keybinds = pluginApi.mainInstance.keybinds
            loading = pluginApi.mainInstance.loading
            hasError = pluginApi.mainInstance.hasError
            errorMessage = pluginApi.mainInstance.errorMessage
        }
        pluginApi.mainInstance.loadKeybinds()
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
            spacing: Style.marginM

            NLabel {
                text: "Niri Keybinds"
                font.bold: true
                font.pixelSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Reload"
                    outlined: true
                    onClicked: pluginApi.mainInstance.loadKeybinds()
                }

                NButton {
                    text: "Save Changes"
                    outlined: true
                    onClicked: pluginApi.mainInstance.saveKeybinds()
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Open Config"
                    outlined: true
                    onClicked: openConfigFile()
                }
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginS

                    Repeater {
                        model: pluginApi?.mainInstance?.keybinds || []

                        NBox {
                            Layout.fillWidth: true
                            padding: Style.marginM
                            radius: Style.radiusM

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Style.marginS

                                RowLayout {
                                    Layout.fillWidth: true

                                    NLabel {
                                        text: modelData.title || "Unnamed"
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    NLabel {
                                        text: modelData.category || ""
                                        color: Color.mOnSurfaceVariant
                                    }
                                }

                                NLabel {
                                    text: modelData.bindings || ""
                                    color: Color.mPrimary
                                    font.family: "monospace"
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    NButton {
                                        text: "Edit"
                                        outlined: true
                                        onClicked: editKeybind(index)
                                    }

                                    NButton {
                                        text: "Delete"
                                        outlined: true
                                        onClicked: deleteKeybind(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            NLabel {
                text: hasError ? errorMessage : ((pluginApi?.mainInstance?.keybinds?.length || 0) + " keybinds loaded")
                color: hasError ? Color.mError : Color.mOnSurfaceVariant
                font.pixelSize: Style.fontSizeS
                Layout.fillWidth: true
            }
        }
    }

    function getConfigPath() {
        var path = pluginApi?.pluginSettings?.configPath || ""
        if (path) return path
        return Quickshell.env("HOME") + "/.config/niri/config.kdl"
    }

    function editKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        var keybind = keybinds[index]
        pluginApi.pluginSettings._editIndex = index
        pluginApi.pluginSettings._editKeybind = keybind
        pluginApi.openPanel(pluginApi.panelOpenScreen)
    }

    function deleteKeybind(index) {
        if (index < 0 || index >= keybinds.length) return
        keybinds.splice(index, 1)
        keybinds = keybinds
        pluginApi.mainInstance.saveKeybinds()
    }

    function openConfigFile() {
        var configPath = getConfigPath()
        Quickshell.execDetached(["xdg-open", configPath])
    }
}