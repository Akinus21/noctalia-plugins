import QtQuick
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    anchors.fill: parent
    
    NLabel {
        text: "Bookmark Panel"
    }
}