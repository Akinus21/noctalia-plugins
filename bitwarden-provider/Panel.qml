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
    property real contentPreferredHeight: 560 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property string panelMode: pluginApi?.pluginSettings?._panelMode || "view"
    readonly property var viewItem: pluginApi?.pluginSettings?._viewItem || null
    readonly property var editItem: pluginApi?.pluginSettings?._editItem || null

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

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

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
        proc.Completed: {
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
        proc.Completed: {
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
        proc.Completed: {
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