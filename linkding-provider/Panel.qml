import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    focus: true

    property var pluginApi: null
    readonly property var geometryPlaceholder: mainContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 360 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property bool isEditMode: pluginApi?.pluginSettings?._panelMode === "edit"
    readonly property var editBookmark: pluginApi?.pluginSettings?._editBookmark || null

    readonly property string linkdingUrl:
        pluginApi?.pluginSettings?.linkdingUrl ||
        pluginApi?.manifest?.metadata?.defaultSettings?.linkdingUrl || ""

    readonly property string apiToken:
        pluginApi?.pluginSettings?.apiToken ||
        pluginApi?.manifest?.metadata?.defaultSettings?.apiToken || ""

    // Form state
    property string urlValue: isEditMode ? (editBookmark?.url || "") : ""
    property string titleValue: isEditMode ? (editBookmark?.title || "") : ""
    property string descValue: isEditMode ? (editBookmark?.description || "") : ""
    property string tagsValue: isEditMode ? ((editBookmark?.tag_names || []).join(", ")) : ""

    property bool saving: false
    property string errorMsg: ""

    Item {
        id: mainContainer
        anchors.fill: parent

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: isEditMode ? "pencil" : "bookmark-plus"
                    pointSize: Style.fontSizeXL
                    color: Color.mPrimary
                }

                NText {
                    text: isEditMode
                        ? (pluginApi?.tr("panel.edit-title") || "Edit Bookmark")
                        : (pluginApi?.tr("panel.create-title") || "Add Bookmark")
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    baseSize: Style.baseWidgetSize
                    onClicked: closeAndClear()
                }
            }

            // Not configured notice
            NBox {
                visible: !linkdingUrl || !apiToken
                Layout.fillWidth: true

                NText {
                    text: pluginApi?.tr("panel.not-configured") || "Linkding not configured. Please set URL and API token in settings."
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }

            // Form
            NBox {
                visible: linkdingUrl && apiToken
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NTextInput {
                        id: urlInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.url-label") || "URL"
                        placeholderText: "https://example.com"
                        text: root.urlValue
                        onTextChanged: root.urlValue = text
                    }

                    NTextInput {
                        id: titleInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.title-label") || "Title"
                        placeholderText: pluginApi?.tr("panel.title-placeholder") || "Bookmark title"
                        text: root.titleValue
                        onTextChanged: root.titleValue = text
                    }

                    NTextInput {
                        id: descInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.desc-label") || "Description"
                        placeholderText: pluginApi?.tr("panel.desc-placeholder") || "Optional description"
                        text: root.descValue
                        onTextChanged: root.descValue = text
                    }

                    NTextInput {
                        id: tagsInput
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.tags-label") || "Tags"
                        placeholderText: pluginApi?.tr("panel.tags-placeholder") || "dev, tools, notes"
                        text: root.tagsValue
                        onTextChanged: root.tagsValue = text
                    }

                    // Error message
                    NText {
                        visible: root.errorMsg !== ""
                        text: root.errorMsg
                        pointSize: Style.fontSizeS
                        color: Color.mError
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    text: pluginApi?.tr("panel.cancel") || "Cancel"
                    enabled: !root.saving
                    onClicked: closeAndClear()
                }

                Item { Layout.fillWidth: true }

                NButton {
                    text: root.saving
                        ? (pluginApi?.tr("panel.saving") || "Saving…")
                        : (isEditMode
                            ? (pluginApi?.tr("panel.save") || "Save")
                            : (pluginApi?.tr("panel.add") || "Add"))
                    highlighted: true
                    enabled: !root.saving && root.urlValue !== ""
                    onClicked: saveBookmark()
                }
            }
        }
    }

    function closeAndClear() {
        pluginApi.pluginSettings._panelMode = null
        pluginApi.pluginSettings._editBookmark = null
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }

    function saveBookmark() {
        if (!root.urlValue) return
        root.saving = true
        root.errorMsg = ""

        var apiUrl = linkdingUrl.replace(/\/$/, "")
        var method = isEditMode ? "PUT" : "POST"
        var endpoint = isEditMode
            ? apiUrl + "/api/bookmarks/" + editBookmark.id + "/"
            : apiUrl + "/api/bookmarks/"

        var payload = {
            url: root.urlValue,
            title: root.titleValue || root.urlValue,
            description: root.descValue,
            tag_names: root.tagsValue.split(",").map(function(t) { return t.trim() }).filter(function(t) { return t !== "" })
        }

        var xhr = new XMLHttpRequest()
        xhr.open(method, endpoint, true)
        xhr.setRequestHeader("Authorization", "Token " + apiToken)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            root.saving = false

            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var saved = JSON.parse(xhr.responseText)
                    // Notify launcher provider to update cache
                    var mainInstance = pluginApi?.mainInstance
                    if (mainInstance && typeof mainInstance.onBookmarkSaved === "function") {
                        mainInstance.onBookmarkSaved(saved)
                    }
                    ToastService.showNotice(
                        isEditMode
                            ? (pluginApi?.tr("panel.saved-edit") || "Bookmark updated")
                            : (pluginApi?.tr("panel.saved-new") || "Bookmark added")
                    )
                    closeAndClear()
                } catch (e) {
                    root.errorMsg = pluginApi?.tr("panel.parse-error") || "Failed to parse response"
                }
            } else {
                root.errorMsg = pluginApi?.tr("panel.save-error") || ("Save failed: " + xhr.status)
                Logger.e("LinkdingPanel", "Save failed:", xhr.status, xhr.responseText)
            }
        }

        xhr.send(JSON.stringify(payload))
    }

    Component.onCompleted: {
        Logger.i("LinkdingPanel", "Panel loaded", isEditMode ? "edit" : "create", "mode")
    }
}