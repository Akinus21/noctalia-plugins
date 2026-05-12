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
    property string addItemType: pluginApi?.pluginSettings?._addItemType || "choose" // "choose" | "login" | "note"

    onVisibleChanged: {
        if (visible && pluginApi) {
            panelMode = pluginApi.pluginSettings._panelMode || "view"
            viewItem  = pluginApi.pluginSettings._viewItem || null
            addItemType = pluginApi.pluginSettings._addItemType || "choose"
            Logger.d("BitwardenPanel", "Visible changed, mode:", panelMode, "addType:", addItemType)
        }
    }

    onAddItemTypeChanged: {
        Logger.d("BitwardenPanel", "addItemType changed to:", addItemType)
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

            // ── LOGIN item type (type 1) ────────────────────────────────────
            ColumnLayout {
                spacing: Style.marginS
                visible: root.viewItem && root.viewItem.type === 1

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
            }

            // ── SECURE NOTE item type (type 2) ────────────────────────────────
            ColumnLayout {
                spacing: Style.marginS
                visible: root.viewItem && root.viewItem.type === 2

                NText { text: "Note"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.notes ? root.viewItem.notes : "-"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                NButton {
                    text: "Copy Note"
                    outlined: true
                    Layout.fillWidth: true
                    visible: root.viewItem && root.viewItem.notes
                    onClicked: {
                        copyToClipboard(root.viewItem.notes)
                        ToastService.showNotice("Note copied")
                    }
                }
            }

            // ── CARD item type (type 3) ───────────────────────────────────────
            ColumnLayout {
                spacing: Style.marginS
                visible: root.viewItem && root.viewItem.type === 3

                NText { text: "Cardholder Name"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.card ? (root.viewItem.card.cardholderName || "-") : "-"
                    Layout.fillWidth: true
                }

                NText { text: "Number"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.card && root.viewItem.card.number ? "**** **** **** " + root.viewItem.card.number.slice(-4) : "-"
                    Layout.fillWidth: true
                }

                NText { text: "Expiration"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.card ? ((root.viewItem.card.expMonth || "") + "/" + (root.viewItem.card.expYear || "")) : "-"
                    Layout.fillWidth: true
                }

                NText { text: "Code"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.card && root.viewItem.card.code ? "****" : "-"
                    Layout.fillWidth: true
                }
                NButton {
                    text: "Copy Code"
                    outlined: true
                    Layout.fillWidth: true
                    visible: root.viewItem && root.viewItem.card && root.viewItem.card.code
                    onClicked: {
                        copyToClipboard(root.viewItem.card.code)
                        ToastService.showNotice("Code copied")
                    }
                }
            }

            // ── IDENTITY item type (type 4) ──────────────────────────────────
            ColumnLayout {
                spacing: Style.marginS
                visible: root.viewItem && root.viewItem.type === 4

                NText { text: "Name"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.identity ? (root.viewItem.identity.firstName || "-") : "-"
                    Layout.fillWidth: true
                }

                NText { text: "Email"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.identity ? (root.viewItem.identity.email || "-") : "-"
                    color: Color.mPrimary
                    Layout.fillWidth: true
                }

                NText { text: "Phone"; font.weight: Font.Bold }
                NText {
                    text: root.viewItem && root.viewItem.identity ? (root.viewItem.identity.phone || "-") : "-"
                    Layout.fillWidth: true
                }
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

        // Step 1: Choose item type
        ColumnLayout {
            id: addChoose
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL
            visible: root.panelMode === "add" && root.addItemType === "choose"

            NText {
                text: "Add Vault Item"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NButton {
                Layout.fillWidth: true
                text: "Login"
                outlined: true
                onClicked: root.addItemType = "login"
            }

            NButton {
                Layout.fillWidth: true
                text: "Secure Note"
                outlined: true
                onClicked: root.addItemType = "note"
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            NButton {
                text: "Cancel"
                outlined: true
                Layout.fillWidth: true
                onClicked: closePanel()
            }
        }

        // Step 2a: Add Login form
        ColumnLayout {
            id: addLoginForm
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL
            visible: root.panelMode === "add" && root.addItemType === "login"

            property string editName: ""
            property string editUsername: ""
            property string editPassword: ""
            property string editUri: ""
            property string statusText: ""
            property bool statusOk: true
            property bool isSaving: false

            NText {
                text: "Add Login"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Name / Title"
                placeholderText: "e.g. github.com"
                text: addLoginForm.editName
                onTextChanged: addLoginForm.editName = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "Username"
                placeholderText: "your@email.com"
                text: addLoginForm.editUsername
                onTextChanged: addLoginForm.editUsername = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "Password"
                placeholderText: "your password"
                text: addLoginForm.editPassword
                onTextChanged: addLoginForm.editPassword = text
            }
            NTextInput {
                Layout.fillWidth: true
                label: "URL"
                placeholderText: "https://github.com"
                text: addLoginForm.editUri
                onTextChanged: addLoginForm.editUri = text
            }

            NText {
                visible: addLoginForm.statusText !== ""
                text: addLoginForm.statusText
                color: addLoginForm.statusOk ? "#4CAF50" : "#F44336"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    text: "Back"
                    outlined: true
                    Layout.fillWidth: true
                    enabled: !addLoginForm.isSaving
                    onClicked: root.addItemType = "choose"
                }
                NButton {
                    text: addLoginForm.isSaving ? "Saving…" : "Save"
                    Layout.fillWidth: true
                    enabled: addLoginForm.editName !== "" && !addLoginForm.isSaving
                    onClicked: saveNewLogin()
                }
            }
        }

        // Step 2b: Add Note form
        ColumnLayout {
            id: addNoteForm
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL
            visible: root.panelMode === "add" && root.addItemType === "note"

            property string editName: ""
            property string editNotes: ""
            property string statusText: ""
            property bool statusOk: true
            property bool isSaving: false

            NText {
                text: "Add Secure Note"
                font.weight: Font.Bold
                pointSize: Style.fontSizeL
                Layout.fillWidth: true
            }

            NTextInput {
                Layout.fillWidth: true
                label: "Name / Title"
                placeholderText: "e.g. My secret note"
                text: addNoteForm.editName
                onTextChanged: addNoteForm.editName = text
            }

            NText {
                text: "Note"
                font.weight: Font.Bold
            }

            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: 200 * Style.uiScaleRatio
                color: Color.mSurface
                radius: Style.radiusM

                TextEdit {
                    id: noteTextArea
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: Style.marginM }
                    color: Color.mOnSurface
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                    readOnly: false
                    text: addNoteForm.editNotes
                    onTextChanged: addNoteForm.editNotes = text
                    property string placeholderText: "Enter your secret note here..."
                    Text {
                        anchors.fill: parent
                        text: noteTextArea.placeholderText
                        color: Color.mOnSurfaceVariant
                        font: noteTextArea.font
                        visible: noteTextArea.text.length === 0 && !noteTextArea.activeFocus
                        z: -1
                    }
                }
            }

            NText {
                visible: addNoteForm.statusText !== ""
                text: addNoteForm.statusText
                color: addNoteForm.statusOk ? "#4CAF50" : "#F44336"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NButton {
                    text: "Back"
                    outlined: true
                    Layout.fillWidth: true
                    enabled: !addNoteForm.isSaving
                    onClicked: root.addItemType = "choose"
                }
                NButton {
                    text: addNoteForm.isSaving ? "Saving…" : "Save"
                    Layout.fillWidth: true
                    enabled: addNoteForm.editName !== "" && !addNoteForm.isSaving
                    onClicked: saveNewNote()
                }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────

    function saveNewLogin() {
        var name     = addLoginForm.editName.trim()
        var username = addLoginForm.editUsername.trim()
        var password = addLoginForm.editPassword.trim()
        var uri      = addLoginForm.editUri.trim()

        if (!name) {
            addLoginForm.statusText = "Name is required"
            addLoginForm.statusOk = false
            return
        }

        addLoginForm.isSaving = true
        addLoginForm.statusText = ""

        var main = pluginApi?.mainInstance
        if (!main || !main.createItem) {
            addLoginForm.statusText = "Provider not ready"
            addLoginForm.statusOk = false
            addLoginForm.isSaving = false
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
            addLoginForm.isSaving = false
            if (success) {
                addLoginForm.statusText = "Item saved"
                addLoginForm.statusOk = true
                ToastService.showNotice("Vault item created")
                addLoginForm.editName = ""
                addLoginForm.editUsername = ""
                addLoginForm.editPassword = ""
                addLoginForm.editUri = ""
                Qt.callLater(closePanel)
            } else {
                addLoginForm.statusText = "Error: " + (message || "Failed")
                addLoginForm.statusOk = false
                Logger.e("BitwardenPanel", "Save login failed:", message)
            }
        })
    }

    function saveNewNote() {
        var name  = addNoteForm.editName.trim()
        var notes = addNoteForm.editNotes.trim()

        if (!name) {
            addNoteForm.statusText = "Name is required"
            addNoteForm.statusOk = false
            return
        }

        addNoteForm.isSaving = true
        addNoteForm.statusText = ""

        var main = pluginApi?.mainInstance
        if (!main || !main.createItem) {
            addNoteForm.statusText = "Provider not ready"
            addNoteForm.statusOk = false
            addNoteForm.isSaving = false
            return
        }

        main.createItem({
            type: 2,
            name: name,
            notes: notes
        }, function(success, message) {
            addNoteForm.isSaving = false
            if (success) {
                addNoteForm.statusText = "Note saved"
                addNoteForm.statusOk = true
                ToastService.showNotice("Secure note created")
                addNoteForm.editName = ""
                addNoteForm.editNotes = ""
                Qt.callLater(closePanel)
            } else {
                addNoteForm.statusText = "Error: " + (message || "Failed")
                addNoteForm.statusOk = false
                Logger.e("BitwardenPanel", "Save note failed:", message)
            }
        })
    }

    function autoTypeLogin() {
        if (!root.viewItem || root.viewItem.type !== 1) return
        var username = root.viewItem.login?.username || ""
        var password = root.viewItem.login?.password || ""
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
        root.addItemType = "choose"
        pluginApi.pluginSettings._panelMode = "view"
        pluginApi.pluginSettings._viewItem = null
        pluginApi.saveSettings()
        if (pluginApi.panelOpenScreen && pluginApi.togglePanel) {
            pluginApi.togglePanel(pluginApi.panelOpenScreen)
        }
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + String(text).replace(/'/g, "'\''") + "' | wl-copy"])
    }
}
