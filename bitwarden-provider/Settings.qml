import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editServerUrl: cfg.serverUrl ?? defaults.serverUrl ?? ""
    property string editEmail: cfg.email ?? defaults.email ?? ""
    property string editPassword: cfg.password || ""
    property bool editAutoType: cfg.autoTypeEnabled ?? defaults.autoTypeEnabled ?? true
    property string editWtypePath: cfg.wtypePath ?? defaults.wtypePath ?? "/home/linuxbrew/.linuxbrew/bin/wtype"

    property string testStatus: ""   // "" | "testing" | "ok" | "err"
    property string testMessage: ""
    property string bwPath: "/home/linuxbrew/.linuxbrew/bin/bw"

    spacing: Style.marginL

    // ── Test runner ────────────────────────────────────────────────────────

    property var _testCb: null

    Process {
        id: testProcess
        property string out: ""

        stdout: SplitParser {
            onRead: function(data) { testProcess.out += data + "\n" }
        }
        stderr: SplitParser {
            onRead: function(data) { Logger.w("BitwardenSettings", "stderr:", data) }
        }
        onExited: function(exitCode, exitStatus) {
            var o = testProcess.out.trim(); testProcess.out = ""
            var cb = root._testCb; root._testCb = null
            Logger.i("BitwardenSettings", "Test step done: exit=" + exitCode + " out=" + o)
            if (cb) cb(o, exitCode)
        }
    }

    function runTest(args, cb) {
        if (testProcess.running) { Logger.w("BitwardenSettings", "Test busy"); return }
        root._testCb = cb
        testProcess.out = ""
        testProcess.command = args
        testProcess.running = true
    }

    function testConnection() {
        var serverUrl = root.editServerUrl
        var email     = root.editEmail
        var password  = root.editPassword
        if (!password || !email) { return }

        root.testStatus = "testing"
        root.testMessage = ""

        var env = Object.assign({}, Qt.application.environment)
        env["BW_PASSWORD"] = password
        testProcess.environment = env

        function doLogin() {
            runTest([bwPath, "login", email, "--passwordenv", "BW_PASSWORD"], function(out, exitCode) {
                if (exitCode !== 0) {
                    root.testStatus = "err"
                    root.testMessage = out || "Login failed (exit=" + exitCode + ")"
                    testProcess.environment = {}
                    return
                }
                // Try unlock to fully validate
                runTest([bwPath, "unlock", "--passwordenv", "BW_PASSWORD", "--raw"], function(uOut, uExit) {
                    testProcess.environment = {}
                    if (uExit === 0 && uOut.trim().length > 20) {
                        root.testStatus = "ok"
                        root.testMessage = "Login successful"
                    } else {
                        root.testStatus = "err"
                        root.testMessage = uOut || "Unlock failed (exit=" + uExit + ")"
                    }
                })
            })
        }

        if (serverUrl) {
            Logger.i("BitwardenSettings", "Setting server:", serverUrl)
            runTest([bwPath, "config", "server", serverUrl], function(out, exitCode) {
                if (exitCode !== 0) {
                    root.testStatus = "err"
                    root.testMessage = out || "Config server failed"
                    testProcess.environment = {}
                    return
                }
                doLogin()
            })
        } else {
            doLogin()
        }
    }

    // ── saveSettings ───────────────────────────────────────────────────────

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.serverUrl       = root.editServerUrl
        pluginApi.pluginSettings.email          = root.editEmail
        pluginApi.pluginSettings.password       = root.editPassword
        pluginApi.pluginSettings.autoTypeEnabled = root.editAutoType
        pluginApi.pluginSettings.wtypePath       = root.editWtypePath
        pluginApi.saveSettings()
        testConnection()
    }

    // ── UI ────────────────────────────────────────────────────────────────

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.serverUrl.label") ?? "Server URL"
        description: pluginApi?.tr("settings.serverUrl.desc") ?? "Your Bitwarden or Vaultwarden server URL"
        placeholderText: "https://vault.bitwarden.com"
        text: root.editServerUrl
        onTextChanged: root.editServerUrl = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.email.label") ?? "Email"
        description: pluginApi?.tr("settings.email.desc") ?? "Your Bitwarden account email"
        placeholderText: "you@example.com"
        text: root.editEmail
        onTextChanged: root.editEmail = text
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NText {
            text: pluginApi?.tr("settings.password.label") ?? "Master Password"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        NText {
            text: pluginApi?.tr("settings.password.desc") ?? "Your master password"
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NBox {
                Layout.fillWidth: true
                implicitHeight: passwordField.implicitHeight + Style.marginM * 2
                radius: Style.radiusM

                TextInput {
                    id: passwordField
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginM }
                    text: root.editPassword
                    echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                    color: Color.mOnSurface
                    font.pixelSize: 14
                    selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    onTextChanged: root.editPassword = text

                    Text {
                        anchors.fill: parent
                        text: "Your master password"
                        color: Color.mOnSurfaceVariant
                        font: passwordField.font
                        visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    }
                }
            }

            NButton {
                id: showPassword
                property bool checked: false
                text: checked ? "Hide" : "Show"
                outlined: true
                onClicked: checked = !checked
            }
        }
    }

    // Auto-type section
    NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: autoTypeContent.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceContainer
        radius: Style.radiusM

        ColumnLayout {
            id: autoTypeContent
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginS

            NText {
                text: "Auto-Type Login"
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            NText {
                text: "Type username + Tab + password into the focused window. Requires wtype (brew install wtype)."
                color: Color.mOnSurfaceVariant
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
            }

            NButton {
                Layout.fillWidth: true
                text: root.editAutoType ? "Auto-Type: ON" : "Auto-Type: OFF"
                outlined: !root.editAutoType
                onClicked: root.editAutoType = !root.editAutoType
            }

            NTextInput {
                Layout.fillWidth: true
                label: "wtype path"
                placeholderText: "/home/linuxbrew/.linuxbrew/bin/wtype"
                text: root.editWtypePath
                onTextChanged: root.editWtypePath = text
            }
        }
    }

    NText {
        visible: root.testStatus !== ""
        text: root.testStatus === "testing" ? "Validating credentials…"
            : root.testStatus === "ok"      ? "Login successful"
            : "Login failed: " + root.testMessage
        color: root.testStatus === "ok"    ? "#4CAF50"
            : root.testStatus === "err"    ? "#F44336"
            : Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    NText {
        text: pluginApi?.tr("settings.hint") ?? "Requires: brew install bitwarden-cli"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
    }
}
