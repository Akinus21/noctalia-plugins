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

    property string panelMode: pluginApi?.pluginSettings?._panelMode || "view"
    property var viewItem: pluginApi?.pluginSettings?._viewItem || null

    onVisibleChanged: {
        if (visible && pluginApi) {
            panelMode = pluginApi.pluginSettings._panelMode || "view"
            viewItem  = pluginApi.pluginSettings._viewItem || null
            Logger.d("BitwardenPanel", "Visible changed, mode:", panelMode)
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        // ── VIEW MODE ───────────────────────────────────────────────────────
        ColumnLayout {
            id: viewLayout
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL
            visible: root.panelMode === "view"

            NText {
                text: root.viewItem ? (root.viewItem.name || "Vault Item") : "Vault Item"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NText { text: "Username"; font.weight: Font.Bold }
            NText {
                text: root.viewItem && root.viewItem.login ? (root.viewItem.login.username || "-") : "-"
                Layout.fillWidth: true
            }
            NButton {
                text: "Copy Username"
                outlined: true
                Layout.fillWidth: true
                visible: root.viewItem && root.viewItem.login && root.viewItem.login.username
                onClicked: {
                    copyToClipboard(root.viewItem.login.username)
                    ToastService.showNotice("Username copied")
                }
            }

            NText { text: "Password"; font.weight: Font.Bold }
            NText {
                text: root.viewItem && root.viewItem.login && root.viewItem.login.password ? "********" : "-"
                Layout.fillWidth: true
            }
            NButton {
                text: "Copy Password"
                outlined: true
                Layout.fillWidth: true
                visible: root.viewItem && root.viewItem.login && root.viewItem.login.password
                onClicked: {
                    copyToClipboard(root.viewItem.login.password)
                    ToastService.showNotice("Password copied")
                }
            }

            NButton {
                text: "Auto-Type Login"
                outlined: true
                Layout.fillWidth: true
                visible: root.viewItem && root.viewItem.login && root.viewItem.login.username && root.viewItem.login.password
                onClicked: {
                    autoTypeLogin()
                }
            }

            NText { text: "URL"; font.weight: Font.Bold }
            NText {
                text: root.viewItem && root.viewItem.login ? (root.viewItem.login.uri || "-") : "-"
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

        // ── ADD MODE ────────────────────────────────────────────────────────
        ColumnLayout {
            id: addForm
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL
            visible: root.panelMode === "add"

            property string editName: ""
            property string editUsername: ""
            property string editPassword: ""
            property string editUri: ""
            property string statusText: ""
            property bool statusOk: true
            property bool isSaving: false

            NText {
                text: "Add Vault Item"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Name"
                placeholderText: "e.g. github.com"
                text: addForm.editName
                onTextChanged: addForm.editName = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "Username"
                placeholderText: "your@email.com"
                text: addForm.editUsername
                onTextChanged: addForm.editUsername = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "Password"
                placeholderText: "your password"
                text: addForm.editPassword
                onTextChanged: addForm.editPassword = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://github.com"
                text: addForm.editUri
                onTextChanged: addForm.editUri = text
            }

            NText {
                visible: addForm.statusText !== ""
                text: addForm.statusText
                color: addForm.statusOk ? "#4CAF50" : "#F44336"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    text: "Cancel"
                    outlined: true
                    Layout.fillWidth: true
                    enabled: !addForm.isSaving
                    onClicked: closePanel()
                }
                NButton {
                    text: addForm.isSaving ? "Saving…" : "Save"
                    Layout.fillWidth: true
                    enabled: addForm.editName !== "" && !addForm.isSaving
                    onClicked: saveNewItem()
                }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────

    function saveNewItem() {
        var name     = addForm.editName.trim()
        var username = addForm.editUsername.trim()
        var password = addForm.editPassword.trim()
        var uri      = addForm.editUri.trim()

        if (!name) {
            addForm.statusText = "Name is required"
            addForm.statusOk = false
            return
        }

        addForm.isSaving = true
        addForm.statusText = ""

        var main = pluginApi?.mainInstance
        if (!main || !main.createItem) {
            addForm.statusText = "Provider not ready"
            addForm.statusOk = false
            addForm.isSaving = false
            return
        }

        main.createItem({
            type: 1,
            name: name,
            login: {
                username: username,
                password: password,
                uris: uri ? [{ uri: uri, match: null }] : []
            }
        }, function(success, message) {
            addForm.isSaving = false
            if (success) {
                addForm.statusText = "Item saved"
                addForm.statusOk = true
                ToastService.showNotice("Vault item created")
                addForm.editName = ""
                addForm.editUsername = ""
                addForm.editPassword = ""
                addForm.editUri = ""
                Qt.callLater(closePanel)
            } else {
                addForm.statusText = "Error: " + (message || "Failed")
                addForm.statusOk = false
                Logger.e("BitwardenPanel", "Save failed:", message)
            }
        })
    }

    function autoTypeLogin() {
        if (!root.viewItem || !root.viewItem.login) return
        var username = root.viewItem.login.username || ""
        var password = root.viewItem.login.password || ""
        if (!username || !password) {
            ToastService.showError("Missing username or password for auto-type")
            return
        }
        var main = pluginApi?.mainInstance
        if (!main || !main.provider) {
            ToastService.showError("Provider not ready")
            return
        }
        main.provider.ensureUnlocked(function() {
            main.provider.autoType(username, password)
        })
        closePanel()
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
        Quickshell.execDetached(["sh", "-c", "echo -n '" + String(text).replace(/'/g, "'\''") + "' | wl-copy"])
    }
}
