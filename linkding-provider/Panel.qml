import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    // ── Injected by Noctalia ─────────────────────────────────────────────
    property var pluginApi: null

    // ── SmartPanel required properties ───────────────────────────────────
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    // ── Preferred dimensions ─────────────────────────────────────────────
    property real contentPreferredWidth:  560 * Style.uiScaleRatio
    property real contentPreferredHeight: 420 * Style.uiScaleRatio

    anchors.fill: parent

    // ── Derived from pluginSettings (set by LauncherProvider) ─────────────
    readonly property string panelMode:
        pluginApi?.pluginSettings?._panelMode || "create"

    readonly property var editBookmark:
        pluginApi?.pluginSettings?._editBookmark || null

    readonly property bool isEdit: panelMode === "edit"

    // ── Local form state ─────────────────────────────────────────────────
    property string formUrl:   ""
    property string formTags:  ""
    property bool   saving:    false

    // ── Reset form when panel opens ───────────────────────────────────────
    onEditBookmarkChanged: resetForm()
    onPanelModeChanged:    resetForm()

    function resetForm() {
        if (isEdit && editBookmark) {
            formUrl  = editBookmark.url        || ""
            formTags = (editBookmark.tag_names || []).join(", ")
        } else {
            formUrl  = ""
            formTags = ""
        }
        saving = false
        urlInput.forceActiveFocus()
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    readonly property string linkdingUrl:
        pluginApi?.pluginSettings?.linkdingUrl || ""

    readonly property string apiToken:
        pluginApi?.pluginSettings?.apiToken || ""

    // ── API calls ─────────────────────────────────────────────────────────

    function save() {
        if (saving) return
        if (!formUrl.trim()) {
            ToastService.showError("URL is required")
            return
        }

        saving = true

        var tags = formTags.split(",")
            .map(function(t) { return t.trim() })
            .filter(function(t) { return t.length > 0 })

        var payload = JSON.stringify({
            url:        formUrl.trim(),
            tag_names:  tags,
            is_archived: false
        })

        var xhr = new XMLHttpRequest()
        var baseUrl = linkdingUrl.replace(/\/$/, "")

        if (isEdit && editBookmark) {
            xhr.open("PATCH", baseUrl + "/api/bookmarks/" + editBookmark.id + "/", true)
        } else {
            xhr.open("POST", baseUrl + "/api/bookmarks/", true)
        }

        xhr.setRequestHeader("Authorization",  "Token " + apiToken)
        xhr.setRequestHeader("Content-Type",   "application/json")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            saving = false

            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var saved = JSON.parse(xhr.responseText)
                    // Notify the LauncherProvider to update its cache
                    var provider = pluginApi?.launcherProvider
                    if (provider && typeof provider.onBookmarkSaved === "function") {
                        provider.onBookmarkSaved(saved)
                    }
                    ToastService.showNotice(isEdit ? "Bookmark updated" : "Bookmark saved")
                    pluginApi.closePanel(pluginApi.panelOpenScreen)
                } catch (e) {
                    Logger.e("LinkdingPanel", "Parse error:", e)
                    ToastService.showError("Unexpected response from Linkding")
                }
            } else if (xhr.status === 0) {
                ToastService.showError("Cannot reach Linkding — are you offline?")
            } else {
                Logger.e("LinkdingPanel", "API error:", xhr.status, xhr.responseText)
                ToastService.showError("Linkding error: " + xhr.status)
            }
        }

        xhr.send(payload)
    }

    function cancel() {
        saving = false
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }

    // ── UI ────────────────────────────────────────────────────────────────

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill:    parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NIcon {
                    icon: root.isEdit ? "bookmark-edit" : "bookmark-plus"
                    color: Color.mPrimary
                    pointSize: Style.fontSizeL
                }

                NText {
                    text: root.isEdit ? "Edit Bookmark" : "New Bookmark"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    onClicked: root.cancel()
                }
            }

            // ── Form card ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusL

                ColumnLayout {
                    anchors {
                        fill:    parent
                        margins: Style.marginL
                    }
                    spacing: Style.marginL

                    // URL field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        NLabel {
                            label: "URL"
                            description: "Linkding will automatically fetch the title and favicon"
                        }

                        NTextInput {
                            id: urlInput
                            Layout.fillWidth: true
                            placeholderText: "https://example.com"
                            text: root.formUrl
                            inputIconName: "link"
                            onTextChanged: root.formUrl = text
                            Keys.onReturnPressed: tagsInput.forceActiveFocus()
                        }
                    }

                    // Tags field
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        NLabel {
                            label: "Tags"
                            description: "Comma-separated list of tags (e.g. dev, tools, linux)"
                        }

                        NTextInput {
                            id: tagsInput
                            Layout.fillWidth: true
                            placeholderText: "dev, tools, linux"
                            text: root.formTags
                            inputIconName: "tags"
                            onTextChanged: root.formTags = text
                            Keys.onReturnPressed: root.save()
                        }
                    }

                    // Hint for edit mode showing current title
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.isEdit && root.editBookmark !== null
                        color: Color.mSurface
                        radius: Style.radiusM
                        implicitHeight: hintRow.implicitHeight + Style.marginM * 2

                        RowLayout {
                            id: hintRow
                            anchors {
                                fill: parent
                                margins: Style.marginM
                            }
                            spacing: Style.marginS

                            NIcon {
                                icon: "info-circle"
                                color: Color.mOnSurfaceVariant
                                pointSize: Style.fontSizeS
                            }

                            NText {
                                text: root.editBookmark
                                    ? ("Title: " + (root.editBookmark.title || "(auto-fetched)"))
                                    : ""
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Spacer
                    Item { Layout.fillHeight: true }
                }
            }

            // ── Actions ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                // Saving indicator
                NText {
                    visible: root.saving
                    text: root.isEdit ? "Saving…" : "Adding…"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                }

                Item {
                    visible: !root.saving
                    Layout.fillWidth: true
                }

                NButton {
                    text: "Cancel"
                    enabled: !root.saving
                    onClicked: root.cancel()
                }

                NButton {
                    text: root.isEdit ? "Save Changes" : "Add Bookmark"
                    highlighted: true
                    enabled: !root.saving && root.formUrl.trim().length > 0
                    onClicked: root.save()
                }
            }
        }
    }

    // ── Keyboard shortcut: Escape to close ────────────────────────────────
    Keys.onEscapePressed: root.cancel()

    Component.onCompleted: {
        resetForm()
        Logger.i("LinkdingPanel", "Panel opened in", root.panelMode, "mode")
    }
}