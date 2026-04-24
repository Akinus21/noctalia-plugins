import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root

    // ── Injected by Noctalia ─────────────────────────────────────────────
    property var pluginApi: null

    spacing: Style.marginM

    // ── Local state ───────────────────────────────────────────────────────
    // Always read from pluginSettings first, fall back to defaultSettings

    property string editUrl:
        pluginApi?.pluginSettings?.linkdingUrl ||
        pluginApi?.manifest?.metadata?.defaultSettings?.linkdingUrl || ""

    property string editToken:
        pluginApi?.pluginSettings?.apiToken ||
        pluginApi?.manifest?.metadata?.defaultSettings?.apiToken || ""

    property int editHours:
        pluginApi?.pluginSettings?.cacheMaxAgeHours ??
        pluginApi?.manifest?.metadata?.defaultSettings?.cacheMaxAgeHours ?? 1

    property int editMinutes:
        pluginApi?.pluginSettings?.cacheMaxAgeMinutes ??
        pluginApi?.manifest?.metadata?.defaultSettings?.cacheMaxAgeMinutes ?? 0

    property int editSeconds:
        pluginApi?.pluginSettings?.cacheMaxAgeSeconds ??
        pluginApi?.manifest?.metadata?.defaultSettings?.cacheMaxAgeSeconds ?? 0

    // Connection test state
    property bool testing:    false
    property string testStatus: ""   // "", "ok", "error"
    property string testMessage: ""

    // ── Section: Connection ───────────────────────────────────────────────

    NLabel {
        label: "Connection"
        description: "Your Linkding instance details"
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Linkding URL"
        description: "Base URL of your Linkding instance (e.g. https://links.yourdomain.com)"
        placeholderText: "https://links.yourdomain.com"
        text: root.editUrl
        onTextChanged: {
            root.editUrl    = text
            root.testStatus = ""
        }
    }

    NTextInput {
        Layout.fillWidth: true
        label: "API Token"
        description: "Found in Linkding → Settings → Integrations → REST API"
        placeholderText: "your-api-token-here"
        text: root.editToken
        onTextChanged: {
            root.editToken  = text
            root.testStatus = ""
        }
    }

    // Test connection button + status
    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
            text: root.testing ? "Testing…" : "Test Connection"
            enabled: !root.testing && root.editUrl.trim().length > 0 && root.editToken.trim().length > 0
            onClicked: root.testConnection()
        }

        // Status badge
        Rectangle {
            visible: root.testStatus !== ""
            color: root.testStatus === "ok" ? Qt.rgba(0.2, 0.8, 0.4, 0.15)
                                            : Qt.rgba(0.9, 0.2, 0.2, 0.15)
            radius: Style.radiusS
            implicitWidth: statusRow.implicitWidth + Style.marginM * 2
            implicitHeight: statusRow.implicitHeight + Style.marginS * 2

            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: Style.marginXS

                NIcon {
                    icon: root.testStatus === "ok" ? "circle-check" : "circle-x"
                    color: root.testStatus === "ok" ? "#33cc66" : "#ff4444"
                    pointSize: Style.fontSizeS
                }

                NText {
                    text: root.testMessage
                    color: root.testStatus === "ok" ? "#33cc66" : "#ff4444"
                    pointSize: Style.fontSizeS
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // ── Divider ───────────────────────────────────────────────────────────

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin:    Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Section: Cache ────────────────────────────────────────────────────

    NLabel {
        label: "Cache"
        description: "How long to keep bookmarks cached before fetching fresh data"
    }

    // Hours / Minutes / Seconds row
    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        // Hours
        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Hours"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                from: 0
                to: 168    // up to 1 week
                value: root.editHours
                onValueChanged: root.editHours = value
            }
        }

        // Minutes
        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Minutes"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                from: 0
                to: 59
                value: root.editMinutes
                onValueChanged: root.editMinutes = value
            }
        }

        // Seconds
        ColumnLayout {
            spacing: Style.marginXS

            NText {
                text: "Seconds"
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }

            NSpinBox {
                from: 0
                to: 59
                value: root.editSeconds
                onValueChanged: root.editSeconds = value
            }
        }

        Item { Layout.fillWidth: true }
    }

    // Computed total as a friendly hint
    NText {
        visible: totalSeconds > 0
        readonly property int totalSeconds:
            root.editHours * 3600 + root.editMinutes * 60 + root.editSeconds
        text: "Cache refreshes every " + formatDuration(totalSeconds)
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant

        function formatDuration(s) {
            var parts = []
            var h = Math.floor(s / 3600)
            var m = Math.floor((s % 3600) / 60)
            var sec = s % 60
            if (h > 0)   parts.push(h   + (h   === 1 ? " hour"   : " hours"))
            if (m > 0)   parts.push(m   + (m   === 1 ? " minute" : " minutes"))
            if (sec > 0) parts.push(sec + (sec === 1 ? " second" : " seconds"))
            return parts.length > 0 ? parts.join(", ") : "0 seconds"
        }
    }

    // Zero-duration warning
    NText {
        visible: root.editHours === 0 && root.editMinutes === 0 && root.editSeconds === 0
        text: "⚠ Cache age of 0 will refresh on every launcher open"
        pointSize: Style.fontSizeS
        color: "#ffaa00"
    }

    // ── Divider ───────────────────────────────────────────────────────────

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin:    Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Section: Cache management ─────────────────────────────────────────

    NLabel {
        label: "Cache Management"
        description: "Force a fresh fetch from Linkding on next launcher open"
    }

    NButton {
        text: "Clear Cache"
        onClicked: root.clearCache()
    }

    // ── Connection test logic ─────────────────────────────────────────────

    function testConnection() {
        testing     = true
        testStatus  = ""
        testMessage = ""

        var xhr = new XMLHttpRequest()
        var url = editUrl.replace(/\/$/, "") + "/api/bookmarks/?limit=1"
        xhr.open("GET", url, true)
        xhr.setRequestHeader("Authorization", "Token " + editToken.trim())

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            testing = false

            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var count = data.count !== undefined ? data.count : "?"
                    testStatus  = "ok"
                    testMessage = "Connected — " + count + " bookmark" + (count === 1 ? "" : "s")
                } catch (e) {
                    testStatus  = "ok"
                    testMessage = "Connected"
                }
            } else if (xhr.status === 401 || xhr.status === 403) {
                testStatus  = "error"
                testMessage = "Invalid API token"
            } else if (xhr.status === 0) {
                testStatus  = "error"
                testMessage = "Cannot reach server"
            } else {
                testStatus  = "error"
                testMessage = "Error " + xhr.status
            }
        }

        xhr.send()
    }

    // ── Cache clear logic ─────────────────────────────────────────────────

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

    // ── saveSettings — called by Noctalia when user clicks Save ───────────

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("LinkdingSettings", "Cannot save: pluginApi is null")
            return
        }

        pluginApi.pluginSettings.linkdingUrl        = root.editUrl.trim()
        pluginApi.pluginSettings.apiToken           = root.editToken.trim()
        pluginApi.pluginSettings.cacheMaxAgeHours   = root.editHours
        pluginApi.pluginSettings.cacheMaxAgeMinutes = root.editMinutes
        pluginApi.pluginSettings.cacheMaxAgeSeconds = root.editSeconds

        pluginApi.saveSettings()
        Logger.i("LinkdingSettings", "Settings saved")
    }

    Component.onCompleted: {
        Logger.i("LinkdingSettings", "Settings UI loaded")
    }
}
