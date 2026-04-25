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

    readonly property bool isEditMode: pluginApi?.pluginSettings?._panelMode === "edit"
    readonly property var editBookmark: pluginApi?.pluginSettings?._editBookmark || null

    Component.onCompleted: {
        console.log("PANEL LOADED", isEditMode ? "EDIT" : "CREATE")
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
                text: isEditMode ? "Edit Bookmark" : "Add Bookmark"
                pointSize: Style.fontSizeXL
                font.weight: Font.Bold
                color: Color.mOnSurface
            }

            NTextInput {
                id: urlInput
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://example.com"
                text: isEditMode ? (editBookmark?.url || "") : ""
            }

            NTextInput {
                id: titleInput
                Layout.fillWidth: true
                label: "Title"
                placeholderText: "Bookmark title"
                text: isEditMode ? (editBookmark?.title || "") : ""
            }

            NTextInput {
                id: tagsInput
                Layout.fillWidth: true
                label: "Tags"
                description: "Comma-separated, no # symbol"
                placeholderText: "dev, tools, notes"
                text: isEditMode ? ((editBookmark?.tag_names || []).join(", ")) : ""
            }

            NTextInput {
                id: descInput
                Layout.fillWidth: true
                label: "Description"
                placeholderText: "Optional description"
                text: isEditMode ? (editBookmark?.description || "") : ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: "Close"
                    onClicked: {
                        pluginApi.pluginSettings._panelMode = null
                        pluginApi.pluginSettings._editBookmark = null
                        pluginApi.closePanel(pluginApi.panelOpenScreen)
                    }
                }

                Item { Layout.fillWidth: true }

                NButton {
                    id: saveButton
                    text: isEditMode ? "Save" : "Add"
                    onClicked: saveBookmark()
                }
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

        saveButton.enabled = false

        var apiUrl = settings.url.replace(/\/$/, "")
        var method = isEditMode ? "PUT" : "POST"
        var endpoint = isEditMode
            ? apiUrl + "/api/bookmarks/" + editBookmark.id + "/"
            : apiUrl + "/api/bookmarks/"

        var xhr = new XMLHttpRequest()
        xhr.open(method, endpoint, true)
        xhr.setRequestHeader("Authorization", "Token " + settings.token)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.onreadystatechange = function() {
            saveButton.enabled = true
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            if (xhr.status === 200 || xhr.status === 201) {
                ToastService.showNotice(isEditMode ? "Bookmark updated" : "Bookmark added")
                pluginApi.pluginSettings._panelMode = null
                pluginApi.pluginSettings._editBookmark = null
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