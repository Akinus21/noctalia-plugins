import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    Component.onCompleted: {
        Logger.i("LinkdingSettings", "Settings UI loaded, pluginApi:", pluginApi)
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("LinkdingSettings", "Cannot save: pluginApi is null")
            return
        }

        pluginApi.pluginSettings.linkdingUrl = editUrlInput.text.trim()
        pluginApi.pluginSettings.apiToken = editTokenInput.text.trim()
        pluginApi.pluginSettings.cacheMaxAgeHours = editHours.value
        pluginApi.pluginSettings.cacheMaxAgeMinutes = editMinutes.value
        pluginApi.pluginSettings.cacheMaxAgeSeconds = editSeconds.value

        pluginApi.saveSettings()
        Logger.i("LinkdingSettings", "Settings saved")
    }

    NLabel {
        label: "Connection"
        description: "Your Linkding instance details"
    }

    NTextInput {
        id: editUrlInput
        Layout.fillWidth: true
        label: "Linkding URL"
        description: "Base URL of your Linkding instance (e.g. https://links.yourdomain.com)"
        placeholderText: "https://links.yourdomain.com"
        text: pluginApi?.pluginSettings?.linkdingUrl || ""
        onTextChanged: testStatus = ""
    }

    NTextInput {
        id: editTokenInput
        Layout.fillWidth: true
        label: "API Token"
        description: "Found in Linkding → Settings → Integrations → REST API"
        placeholderText: "your-api-token-here"
        text: pluginApi?.pluginSettings?.apiToken || ""
        onTextChanged: testStatus = ""
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
            text: testing ? "Testing…" : "Test Connection"
            enabled: !testing && editUrlInput.text.trim().length > 0 && editTokenInput.text.trim().length > 0
            onClicked: testConnection()
        }

        Rectangle {
            visible: testStatus !== ""
            color: testStatus === "ok" ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(0.9, 0.2, 0.2, 0.15)
            radius: Style.radiusS
            implicitWidth: statusRow.implicitWidth + Style.marginM * 2
            implicitHeight: statusRow.implicitHeight + Style.marginS * 2

            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: Style.marginXS

                NIcon {
                    icon: testStatus === "ok" ? "circle-check" : "circle-x"
                    color: testStatus === "ok" ? "#33cc66" : "#ff4444"
                    pointSize: Style.fontSizeS
                }

                NText {
                    text: testMessage
                    color: testStatus === "ok" ? "#33cc66" : "#ff4444"
                    pointSize: Style.fontSizeS
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    property bool testing: false
    property string testStatus: ""
    property string testMessage: ""

    function testConnection() {
        testing = true
        testStatus = ""
        testMessage = ""

        var xhr = new XMLHttpRequest()
        var url = editUrlInput.text.replace(/\/$/, "") + "/api/bookmarks/?limit=1"
        xhr.open("GET", url, true)
        xhr.setRequestHeader("Authorization", "Token " + editTokenInput.text.trim())

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            testing = false

            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var count = data.count !== undefined ? data.count : "?"
                    testStatus = "ok"
                    testMessage = "Connected — " + count + " bookmark" + (count === 1 ? "" : "s")
                } catch (e) {
                    testStatus = "ok"
                    testMessage = "Connected"
                }
            } else if (xhr.status === 401 || xhr.status === 403) {
                testStatus = "error"
                testMessage = "Invalid API token"
            } else if (xhr.status === 0) {
                testStatus = "error"
                testMessage = "Cannot reach server"
            } else {
                testStatus = "error"
                testMessage = "Error " + xhr.status
            }
        }

        xhr.send()
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    NLabel {
        label: "Cache"
        description: "How long to keep bookmarks cached before fetching fresh data"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Hours"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                id: editHours
                from: 0
                to: 168
                value: pluginApi?.pluginSettings?.cacheMaxAgeHours ?? 1
                onValueChanged: {}
            }
        }

        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Minutes"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                id: editMinutes
                from: 0
                to: 59
                value: pluginApi?.pluginSettings?.cacheMaxAgeMinutes ?? 0
                onValueChanged: {}
            }
        }

        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Seconds"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                id: editSeconds
                from: 0
                to: 59
                value: pluginApi?.pluginSettings?.cacheMaxAgeSeconds ?? 0
                onValueChanged: {}
            }
        }

        Item { Layout.fillWidth: true }
    }

    NText {
        visible: totalSeconds > 0
        readonly property int totalSeconds: editHours.value * 3600 + editMinutes.value * 60 + editSeconds.value
        text: "Cache refreshes every " + formatDuration(totalSeconds)
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant

        function formatDuration(s) {
            var parts = []
            var h = Math.floor(s / 3600)
            var m = Math.floor((s % 3600) / 60)
            var sec = s % 60
            if (h > 0) parts.push(h + (h === 1 ? " hour" : " hours"))
            if (m > 0) parts.push(m + (m === 1 ? " minute" : " minutes"))
            if (sec > 0) parts.push(sec + (sec === 1 ? " second" : " seconds"))
            return parts.length > 0 ? parts.join(", ") : "0 seconds"
        }
    }

    NText {
        visible: editHours.value === 0 && editMinutes.value === 0 && editSeconds.value === 0
        text: "⚠ Cache age of 0 will refresh on every launcher open"
        pointSize: Style.fontSizeS
        color: "#ffaa00"
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    NLabel {
        label: "Cache Management"
        description: "Force a fresh fetch from Linkding on next launcher open"
    }

    NButton {
        text: "Clear Cache"
        onClicked: clearCache()
    }

    FileView {
        id: cacheClearer
        path: (pluginApi?.pluginDir || "") + "/cache.json"
        watchChanges: false
    }

    function clearCache() {
        cacheClearer.setText("{}")
        ToastService.showNotice("Cache cleared — will refresh on next open")
        Logger.i("LinkdingSettings", "Cache cleared by user")
    }
}