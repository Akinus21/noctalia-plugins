import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Window {
    id: root
    width: 400 * Style.uiScaleRatio
    height: 350 * Style.uiScaleRatio
    color: Color.mSurface
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint

    property var pluginApi: null
    property string mode: "create"  // "create" or "edit"
    property var bookmark: null

    property string formUrl: ""
    property string formTags: ""
    property bool saving: false

    readonly property string linkdingUrl: pluginApi?.pluginSettings?.linkdingUrl || ""
    readonly property string apiToken: pluginApi?.pluginSettings?.apiToken || ""

    Component.onCompleted: {
        if (mode === "edit" && bookmark) {
            formUrl = bookmark.url || ""
            formTags = (bookmark.tag_names || []).join(", ")
        }
        urlInput.forceActiveFocus()
        Logger.i("LinkdingBookmarkWindow", "Window created, mode:", mode)
    }

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

        if (mode === "edit" && bookmark) {
            xhr.open("PATCH", baseUrl + "/api/bookmarks/" + bookmark.id + "/", true)
        } else {
            xhr.open("POST", baseUrl + "/api/bookmarks/", true)
        }

        xhr.setRequestHeader("Authorization", "Token " + apiToken)
        xhr.setRequestHeader("Content-Type", "application/json")

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            saving = false

            if (xhr.status === 200 || xhr.status === 201) {
                try {
                    var saved = JSON.parse(xhr.responseText)
                    var provider = pluginApi?.launcherProvider
                    if (provider && typeof provider.onBookmarkSaved === "function") {
                        provider.onBookmarkSaved(saved)
                    }
                    ToastService.showNotice(mode === "edit" ? "Bookmark updated" : "Bookmark saved")
                    close()
                } catch (e) {
                    Logger.e("LinkdingBookmarkWindow", "Parse error:", e)
                    ToastService.showError("Unexpected response")
                }
            } else if (xhr.status === 0) {
                ToastService.showError("Cannot reach Linkding")
            } else {
                Logger.e("LinkdingBookmarkWindow", "API error:", xhr.status, xhr.responseText)
                ToastService.showError("Linkding error: " + xhr.status)
            }
        }

        xhr.send(payload)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginL

        NLabel {
            label: mode === "edit" ? "Edit Bookmark" : "New Bookmark"
        }

        NTextInput {
            id: urlInput
            Layout.fillWidth: true
            label: "URL"
            placeholderText: "https://example.com"
            text: root.formUrl
            onTextChanged: root.formUrl = text
        }

        NTextInput {
            id: tagsInput
            Layout.fillWidth: true
            label: "Tags"
            placeholderText: "dev, tools"
            text: root.formTags
            onTextChanged: root.formTags = text
        }

        Rectangle {
            Layout.fillWidth: true
            visible: mode === "edit"
            color: Color.mSurfaceVariant
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
                    text: "Title: " + (bookmark.title || "(auto-fetched)")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
                text: "Cancel"
                onClicked: close()
            }

            NButton {
                text: mode === "edit" ? "Save Changes" : "Add Bookmark"
                highlighted: true
                enabled: !root.saving && root.formUrl.trim().length > 0
                onClicked: root.save()
            }
        }
    }
}