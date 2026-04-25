import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 480 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property string panelMode: pluginApi?.pluginSettings?._panelMode || "view"
    readonly property var viewItem: pluginApi?.pluginSettings?._viewItem || null
    readonly property var editItem: pluginApi?.pluginSettings?._editItem || null

    // Setup wizard state
    property int setupStep: 1
    property bool bwInstalled: pluginApi?.pluginSettings?.bwAvailable || false
    property bool vaultUnlocked: pluginApi?.mainInstance?.unlocked || false
    property string vaultUrl: pluginApi?.pluginSettings?.vaultUrl || ""
    property string masterPassword: ""

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

            // Header
            RowLayout {
                Layout.fillWidth: true

                NLabel {
                    text: {
                        if (panelMode === "setup") return "Bitwarden Setup"
                        if (panelMode === "view") return (viewItem?.name || "Vault Item")
                        if (panelMode === "edit") return "Edit Item"
                        return "New Item"
                    }
                    font.bold: true
                    font.pixelSize: Style.fontSizeL
                    Layout.fillWidth: true
                }

                NIconButton {
                    iconName: "x"
                    isTablerIcon: true
                    onClicked: closePanel()
                }
            }

            // Setup wizard
            Loader {
                active: panelMode === "setup"
                visible: active
                Layout.fillWidth: true
                Layout.fillHeight: true

                sourceComponent: ColumnLayout {
                    spacing: Style.marginL
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Step indicator
                    NLabel {
                        text: "Step " + root.setupStep + " of 3"
                        font.pixelSize: Style.fontSizeS
                        color: Color.mPrimary
                    }

                    // Step 1: Check bw installation
                    Loader {
                        active: root.setupStep === 1
                        visible: active
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        sourceComponent: ColumnLayout {
                            spacing: Style.marginL
                            Layout.fillWidth: true

                            NLabel {
                                text: bwInstalled ? "✓ Bitwarden CLI is installed" : "✗ Bitwarden CLI not found"
                                font.bold: true
                                color: bwInstalled ? Color.mPrimary : Color.mError
                            }

                            NLabel {
                                text: bwInstalled
                                    ? "You can proceed to the next step."
                                    : "The Bitwarden CLI is required to access your vault."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            ColumnLayout {
                                visible: !bwInstalled
                                spacing: Style.marginM
                                Layout.fillWidth: true

                                NButton {
                                    text: "Download Bitwarden CLI"
                                    outlined: true
                                    Layout.fillWidth: true
                                    onClicked: Quickshell.execDetached(["xdg-open", "https://bitwarden.com/download"])
                                }

                                NButton {
                                    text: "Install via package manager"
                                    outlined: true
                                    Layout.fillWidth: true
                                    onClicked: {
                                        ToastService.showNotice("Installing bw CLI...")
                                        var proc = Quickshell.execDetached([
                                            "sh", "-c",
                                            "command -v apt >/dev/null 2>&1 && sudo apt install -y bitwarden-cli || command -v pacman >/dev/null 2>&1 && sudo pacman -S bitwarden-cli || command -v brew >/dev/null 2>&1 && brew install bitwarden-cli || echo 'unsupported'"
                                        ])
                                        proc.onCompleted: {
                                            if (proc.exitCode === 0) {
                                                bwInstalled = true
                                                pluginApi.pluginSettings.bwAvailable = true
                                                ToastService.showNotice("bw CLI installed!")
                                            } else {
                                                ToastService.showNotice("Install failed — try downloading from bitwarden.com")
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true; Layout.fillWidth: true }

                            NButton {
                                text: bwInstalled ? "Next →" : "Skip (install manually)"
                                highlighted: bwInstalled
                                Layout.fillWidth: true
                                onClicked: {
                                    root.setupStep = 2
                                }
                            }
                        }
                    }

                    // Step 2: Vault URL
                    Loader {
                        active: root.setupStep === 2
                        visible: active
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        sourceComponent: ColumnLayout {
                            spacing: Style.marginL
                            Layout.fillWidth: true

                            NLabel {
                                text: "Configure Vault URL"
                                font.bold: true
                            }

                            NLabel {
                                text: "Enter your Bitwarden or vaultwarden server URL. Leave empty for official Bitwarden cloud."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            NTextInput {
                                id: setupVaultUrlInput
                                Layout.fillWidth: true
                                label: "Vault URL (optional)"
                                placeholderText: "https://bitwarden.example.com"
                                text: root.vaultUrl
                                onTextChanged: root.vaultUrl = text
                            }

                            Item { Layout.fillHeight: true; Layout.fillWidth: true }

                            RowLayout {
                                spacing: Style.marginM
                                Layout.fillWidth: true

                                NButton {
                                    text: "← Back"
                                    outlined: true
                                    Layout.fillWidth: true
                                    onClicked: root.setupStep = 1
                                }

                                NButton {
                                    text: "Next →"
                                    highlighted: true
                                    Layout.fillWidth: true
                                    onClicked: {
                                        pluginApi.pluginSettings.vaultUrl = root.vaultUrl
                                        pluginApi.saveSettings()
                                        root.setupStep = 3
                                    }
                                }
                            }
                        }
                    }

                    // Step 3: Unlock vault
                    Loader {
                        active: root.setupStep === 3
                        visible: active
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        sourceComponent: ColumnLayout {
                            spacing: Style.marginL
                            Layout.fillWidth: true

                            NLabel {
                                text: vaultUnlocked ? "✓ Vault is unlocked" : "Unlock Your Vault"
                                font.bold: true
                                color: vaultUnlocked ? Color.mPrimary : Color.mOnSurface
                            }

                            NLabel {
                                text: vaultUnlocked
                                    ? "Your session is active. The session token has been saved."
                                    : "Enter your master password to unlock your vault and save a session token."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            NTextInput {
                                id: masterPasswordInput
                                Layout.fillWidth: true
                                label: "Master Password"
                                placeholderText: "Your master password"
                                echoMode: TextInput.Password
                                visible: !vaultUnlocked
                                onTextChanged: masterPassword = text
                                text: masterPassword
                            }

                            NButton {
                                id: unlockButton
                                text: "Unlock Vault"
                                visible: !vaultUnlocked
                                Layout.fillWidth: true
                                enabled: masterPassword.length > 0 && !unlocking
                                onClicked: unlockVault()
                            }

                            Loader {
                                active: unlocking
                                visible: active
                                sourceComponent: NLabel {
                                    text: "Unlocking..."
                                    color: Color.mPrimary
                                }
                            }

                            Item { Layout.fillHeight: true; Layout.fillWidth: true }

                            RowLayout {
                                spacing: Style.marginM
                                Layout.fillWidth: true

                                NButton {
                                    text: "← Back"
                                    outlined: true
                                    Layout.fillWidth: true
                                    onClicked: root.setupStep = 2
                                }

                                NButton {
                                    text: vaultUnlocked ? "Done ✓" : "Skip"
                                    highlighted: vaultUnlocked
                                    Layout.fillWidth: true
                                    onClicked: {
                                        if (vaultUnlocked) {
                                            closePanel()
                                        } else {
                                            closePanel()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Item view/edit (when NOT in setup mode)
            Loader {
                active: panelMode !== "setup"
                visible: active
                Layout.fillWidth: true
                Layout.fillHeight: true

                sourceComponent: ColumnLayout {
                    spacing: Style.marginL
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    NLabel {
                        text: {
                            if (panelMode === "view") return (viewItem?.name || "Vault Item")
                            if (panelMode === "edit") return "Edit Item"
                            return "New Item"
                        }
                        font.bold: true
                        font.pixelSize: Style.fontSizeL
                        Layout.fillWidth: true
                    }

                    NTextInput {
                        id: nameInput
                        Layout.fillWidth: true
                        label: "Name"
                        placeholderText: "Item name"
                        text: {
                            if (panelMode === "edit" || panelMode === "create") {
                                return panelMode === "edit" ? (editItem?.name || "") : ""
                            }
                            return viewItem?.name || ""
                        }
                    }

                    NTextInput {
                        id: usernameInput
                        Layout.fillWidth: true
                        label: "Username"
                        placeholderText: "Username or email"
                        text: {
                            if (panelMode === "edit" || panelMode === "create") {
                                return panelMode === "edit" ? (editItem?.login?.username || "") : ""
                            }
                            return viewItem?.login?.username || ""
                        }
                    }

                    NTextInput {
                        id: passwordInput
                        Layout.fillWidth: true
                        label: "Password"
                        placeholderText: "Password"
                        text: {
                            if (panelMode === "edit" || panelMode === "create") {
                                return panelMode === "edit" ? (editItem?.login?.password || "") : ""
                            }
                            return viewItem?.login?.password || ""
                        }
                        echoMode: TextInput.Password
                    }

                    NTextInput {
                        id: urlInput
                        Layout.fillWidth: true
                        label: "URL"
                        placeholderText: "https://example.com"
                        text: {
                            if (panelMode === "edit" || panelMode === "create") {
                                return panelMode === "edit" ? (editItem?.login?.uri || "") : ""
                            }
                            return viewItem?.login?.uri || ""
                        }
                    }

                    NTextInput {
                        id: notesInput
                        Layout.fillWidth: true
                        label: "Notes"
                        placeholderText: "Optional notes"
                        text: {
                            if (panelMode === "edit" || panelMode === "create") {
                                return panelMode === "edit" ? (editItem?.notes || "") : ""
                            }
                            return viewItem?.notes || ""
                        }
                        multiline: true
                    }

                    Item { Layout.fillHeight: true; Layout.fillWidth: true }

                    RowLayout {
                        spacing: Style.marginM
                        Layout.fillWidth: true

                        NButton {
                            id: actionButton
                            text: panelMode === "view" ? "Edit" : (panelMode === "create" ? "Create" : "Save")
                            Layout.fillWidth: true
                            onClicked: handlePrimaryAction()
                        }

                        NButton {
                            text: panelMode === "view" ? "Delete" : "Cancel"
                            outlined: true
                            Layout.fillWidth: true
                            onClicked: handleSecondaryAction()
                        }
                    }

                    Loader {
                        active: panelMode === "view" && viewItem?.login?.password
                        visible: active
                        Layout.fillWidth: true

                        sourceComponent: NButton {
                            text: "Copy Password"
                            outlined: true
                            Layout.fillWidth: true
                            onClicked: {
                                copyToClipboard(viewItem.login.password)
                                ToastService.showNotice("Password copied")
                            }
                        }
                    }
                }
            }
        }
    }

    property bool unlocking: false

    function unlockVault() {
        if (!masterPassword) return
        unlocking = true
        unlockButton.enabled = false

        var password = masterPassword.replace(/"/g, "\\\"")
        var urlArg = vaultUrl ? "--url \"" + vaultUrl.replace(/"/g, "\\\"") + "\"" : ""

        var proc = Quickshell.execDetached([
            "sh", "-c",
            "BW_PASSWORD=\"" + password + "\" bw unlock " + urlArg + " --passwordenv --raw"
        ])
        proc.onCompleted: {
            unlocking = false
            unlockButton.enabled = true

            if (proc.exitCode === 0) {
                var token = String(proc.readAll()).trim()
                if (token && token.length > 10) {
                    pluginApi.pluginSettings.sessionToken = token
                    pluginApi.saveSettings()
                    vaultUnlocked = true
                    if (pluginApi.mainInstance) {
                        pluginApi.mainInstance.unlocked = true
                        pluginApi.mainInstance.sessionToken = token
                        pluginApi.mainInstance.loadItems()
                    }
                    ToastService.showNotice("Vault unlocked!")
                } else {
                    ToastService.showNotice("Unlock failed — check your password")
                }
            } else {
                Logger.e("BitwardenProvider", "Unlock failed:", proc.exitCode)
                ToastService.showNotice("Unlock failed — check your password")
            }
        }
    }

    function handlePrimaryAction() {
        if (panelMode === "view") {
            pluginApi.pluginSettings._panelMode = "edit"
            pluginApi.pluginSettings._editItem = viewItem
            pluginApi.saveSettings()
            return
        }

        if (!nameInput.text) {
            ToastService.showNotice("Name is required")
            return
        }

        var sessionToken = getSessionToken()
        if (!sessionToken) {
            ToastService.showNotice("Vault is locked")
            return
        }

        var item = {
            name: nameInput.text,
            type: "login",
            login: {
                username: usernameInput.text,
                password: passwordInput.text,
                uris: urlInput.text ? [{ uri: urlInput.text }] : []
            },
            notes: notesInput.text
        }

        if (panelMode === "edit" && editItem?.id) {
            item.id = editItem.id
            updateItem(item, sessionToken)
        } else {
            createItem(item, sessionToken)
        }
    }

    function handleSecondaryAction() {
        if (panelMode === "view") {
            confirmDelete()
        } else {
            closePanel()
        }
    }

    function updateItem(item, sessionToken) {
        var jsonStr = JSON.stringify(item).replace(/'/g, "'\\''")
        var cmd = "bw get item '" + item.id + "' --sessionid " + sessionToken + " | jq -c '"
        cmd += ".name=\"" + item.name + "\" | "
        cmd += ".login.username=\"" + (item.login.username || "") + "\" | "
        cmd += ".login.password=\"" + (item.login.password || "") + "\" | "
        cmd += ".login.uris=[{\"uri\":\"" + (item.login.uris?.[0]?.uri || "") + "\"}] | "
        cmd += ".notes=\"" + (item.notes || "") + "\""
        cmd += "' | bw edit item '" + item.id + "' --sessionid " + sessionToken

        var proc = Quickshell.execDetached(["sh", "-c", cmd])
        proc.onCompleted: {
            if (proc.exitCode === 0) {
                ToastService.showNotice("Item updated")
                closePanel()
                if (pluginApi.mainInstance) pluginApi.mainInstance.loadItems()
            } else {
                Logger.e("BitwardenProvider", "Update failed:", proc.exitCode)
                ToastService.showNotice("Update failed")
            }
        }
    }

    function createItem(item, sessionToken) {
        var jsonStr = JSON.stringify(item).replace(/'/g, "'\\''")
        var proc = Quickshell.execDetached([
            "sh", "-c",
            "echo '" + jsonStr + "' | bw create item --sessionid " + sessionToken
        ])
        proc.onCompleted: {
            if (proc.exitCode === 0) {
                ToastService.showNotice("Item created")
                closePanel()
                if (pluginApi.mainInstance) pluginApi.mainInstance.loadItems()
            } else {
                Logger.e("BitwardenProvider", "Create failed:", proc.exitCode)
                ToastService.showNotice("Create failed")
            }
        }
    }

    property string pendingDeleteId: ""

    function confirmDelete() {
        if (pendingDeleteId !== String(viewItem?.id)) {
            pendingDeleteId = String(viewItem?.id)
            ToastService.showNotice("Press Delete again to confirm")
            return
        }
        pendingDeleteId = ""
        deleteItem()
    }

    function deleteItem() {
        if (!viewItem?.id) return

        var sessionToken = getSessionToken()
        if (!sessionToken) {
            ToastService.showNotice("Vault is locked")
            return
        }

        var proc = Quickshell.execDetached([
            "bw", "delete", "item", viewItem.id, "--sessionid", sessionToken
        ])
        proc.onCompleted: {
            if (proc.exitCode === 0) {
                ToastService.showNotice("Item deleted")
                closePanel()
                if (pluginApi.mainInstance) pluginApi.mainInstance.loadItems()
            } else {
                Logger.e("BitwardenProvider", "Delete failed:", proc.exitCode)
                ToastService.showNotice("Delete failed")
            }
        }
    }

    function closePanel() {
        pluginApi.pluginSettings._panelMode = "view"
        pluginApi.pluginSettings._viewItem = null
        pluginApi.pluginSettings._editItem = null
        pluginApi.saveSettings()
        pluginApi.closePanel(pluginApi.panelOpenScreen)
    }

    function getSessionToken() {
        if (pluginApi?.pluginSettings?.sessionToken) {
            return pluginApi.pluginSettings.sessionToken
        }
        return ""
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "echo -n '" + String(text).replace(/'/g, "'\\''") + "' | wl-copy"])
    }
}