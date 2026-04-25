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
    property real contentPreferredHeight: 560 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    Component.onCompleted: {
        console.log("PANEL LOADED")
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
                text: "Linkding Bookmarks"
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
            }

            NTextInput {
                id: urlInput
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://example.com"
            }

            NTextInput {
                id: titleInput
                Layout.fillWidth: true
                label: "Title"
                placeholderText: "Bookmark title"
            }

            NTextInput {
                id: tagsInput
                Layout.fillWidth: true
                label: "Tags"
                description: "Comma-separated, no # symbol"
                placeholderText: "dev, tools, notes"
            }

            NTextInput {
                id: descInput
                Layout.fillWidth: true
                label: "Description"
                placeholderText: "Optional description"
            }

            NButton {
                text: "Close"
                onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
            }

            NButton {
                id: addButton
                text: "Add"
                onClicked: saveBookmark()
            }
        }
    }

    function getLinkdingSettings() {
        return {
            url: pluginApi?.pluginSettings?.linkdingUrl || "",
            token: pluginApi?.pluginSettings?.apiToken || ""
        }
    }

    function saveBookmark() {
        var settings = getLinkdingSettings()
        if (!settings.url || !settings.token) {
            ToastService.showError("Linkding not configured")
            return
        }
        if (!urlInput.text) {
            ToastService.showError("URL is required")
            return
        }

        addButton.enabled = false

        var apiUrl = settings.url.replace(/\/$/, "")
        var xhr = new XMLHttpRequest()
        xhr.open("POST", apiUrl + "/api/bookmarks/", true)
        xhr.setRequestHeader("Authorization", "Token " + settings.token)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.onreadystatechange = function() {
            addButton.enabled = true
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 201) {
                ToastService.showNotice("Bookmark added")
                pluginApi.closePanel(pluginApi.panelOpenScreen)
            } else {
                ToastService.showError("Failed: " + xhr.status)
            }
        }

        var payload = {
            url: urlInput.text,
            title: titleInput.text || urlInput.text,
            description: descInput.text,
            tag_names: tagsInput.text.split(",").map(function(t) { return t.trim() }).filter(function(t) { return t !== "" })
        }

        xhr.send(JSON.stringify(payload))
    }
}