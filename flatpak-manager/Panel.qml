import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: contentRect
  property real contentPreferredWidth: 700 * Style.uiScaleRatio
  property real contentPreferredHeight: 600 * Style.uiScaleRatio
  readonly property bool allowAttach: true

  anchors.fill: parent

  property var allFlatpaks: []
  property var runningFlatpaks: []
  property var updateableFlatpaks: []
  property var remotes: []
  property var searchResults: []
  property bool loading: false
  property bool loadingSearch: false
  property string errorMessage: ""
  property string selectedTab: "installed"
  property string searchQuery: ""

  property var selectedFlatpak: pluginApi?.pluginSettings?._selectedFlatpak || null
  property string panelMode: pluginApi?.pluginSettings?._panelMode || "installed"

  Component.onCompleted: refreshAll()

  Timer {
    id: searchDebounceTimer
    interval: 300
    onTriggered: if (root.searchQuery.length >= 2) searchFlatpaks(root.searchQuery)
  }

  Process {
    id: listInstalledProcess

    stdout: SplitParser {
      onRead: function(data) { listInstalledProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakPanel", "list stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseInstalledList(listInstalledProcess_out)
      listInstalledProcess_out = ""
    }
  }

  property string listInstalledProcess_out: ""

  Process {
    id: listRunningProcess

    stdout: SplitParser {
      onRead: function(data) { listRunningProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakPanel", "running stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseRunningList(listRunningProcess_out)
      listRunningProcess_out = ""
    }
  }

  property string listRunningProcess_out: ""

  Process {
    id: listUpdatesProcess

    stdout: SplitParser {
      onRead: function(data) { listUpdatesProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakPanel", "updates stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseUpdatesList(listUpdatesProcess_out)
      listUpdatesProcess_out = ""
    }
  }

  property string listUpdatesProcess_out: ""

  Process {
    id: listRemotesProcess

    stdout: SplitParser {
      onRead: function(data) { listRemotesProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakPanel", "remotes stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseRemotesList(listRemotesProcess_out)
      listRemotesProcess_out = ""
    }
  }

  property string listRemotesProcess_out: ""

  Process {
    id: searchProcess

    stdout: SplitParser {
      onRead: function(data) { searchProcess_out += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { Logger.w("FlatpakPanel", "search stderr:", data) }
    }
    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      parseSearchResults(searchProcess_out)
      searchProcess_out = ""
    }
  }

  property string searchProcess_out: ""

  Process {
    id: actionProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        ToastService.showNotice(root._actionFlatpak + " " + root._actionName + "ed")
        refreshAll()
      } else {
        ToastService.showError(root._actionFlatpak + " " + root._actionName + " failed")
      }
      root._actionFlatpak = ""
      root._actionName = ""
    }
  }

  property string _actionFlatpak: ""
  property string _actionName: ""

  Rectangle {
    id: contentRect
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.title") || "Flatpak Manager"
          pointSize: Style.fontSizeXL
          font.weight: Font.Bold
          color: Color.mOnSurface
        }

        Item { Layout.fillWidth: true }

        NButton {
          text: pluginApi?.tr("panel.refresh") || "Refresh"
          outlined: true
          onClicked: refreshAll()
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NButton {
          text: pluginApi?.tr("panel.installed") || "Installed"
          outlined: selectedTab !== "installed"
          onClicked: { selectedTab = "installed"; refreshInstalled() }
        }
        NButton {
          text: pluginApi?.tr("panel.browse") || "Browse"
          outlined: selectedTab !== "browse"
          onClicked: { selectedTab = "browse"; if (searchResults.length === 0) loadBrowseRecommendations() }
        }
        NButton {
          text: pluginApi?.tr("panel.updates") || "Updates"
          outlined: selectedTab !== "updates"
          onClicked: { selectedTab = "updates"; checkForUpdates() }
        }
        NButton {
          text: pluginApi?.tr("panel.remotes") || "Remotes"
          outlined: selectedTab !== "remotes"
          onClicked: { selectedTab = "remotes"; refreshRemotes() }
        }
        NButton {
          text: pluginApi?.tr("panel.running") || "Running"
          outlined: selectedTab !== "running"
          onClicked: { selectedTab = "running"; refreshRunning() }
        }
      }

      NText {
        visible: loading
        text: pluginApi?.tr("panel.loading") || "Loading..."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }

      NText {
        visible: errorMessage !== ""
        text: errorMessage
        color: Color.mError
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }

      // Installed Tab
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: selectedTab === "installed"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginS

          Repeater {
            id: installedRepeater
            model: sortedInstalled

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || modelData.id || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.id || ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                  NText {
                    text: (modelData.version ? "v" + modelData.version : "") + (modelData.origin ? " — " + modelData.origin : "")
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: pluginApi?.tr("panel.run") || "Run"
                  outlined: true
                  onClicked: runFlatpak(modelData.id, modelData.name)
                }

                NButton {
                  text: pluginApi?.tr("panel.update") || "Update"
                  outlined: true
                  onClicked: updateFlatpak(modelData.id, modelData.name)
                }

                NButton {
                  text: pluginApi?.tr("panel.uninstall") || "Uninstall"
                  outlined: true
                  onClicked: uninstallFlatpak(modelData.id, modelData.name)
                }
              }
            }
          }
        }
      }

      // Browse/Search Tab
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: selectedTab === "browse"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          NTextInput {
            id: searchInput
            Layout.fillWidth: true
            label: pluginApi?.tr("panel.searchLabel")
            placeholderText: pluginApi?.tr("panel.searchHint") || "Type to search..."
            text: root.searchQuery
            onTextChanged: {
              root.searchQuery = text
              searchDebounceTimer.restart()
              if (text.length === 0) loadBrowseRecommendations()
            }
          }

          NButton {
            text: pluginApi?.tr("panel.refreshAppstream") || "Refresh Appstream"
            outlined: true
            onClicked: updateAppstream()
          }

          NText {
            visible: loadingSearch
            text: pluginApi?.tr("panel.loading") || "Loading..."
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }

          Repeater {
            id: searchRepeater
            model: searchResults

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || modelData.application || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.description || ""
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                  }
                  NText {
                    text: modelData.application || modelData.id || ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: pluginApi?.tr("panel.install") || "Install"
                  outlined: true
                  onClicked: installFlatpak(modelData.application || modelData.id, modelData.name)
                }

                NButton {
                  text: pluginApi?.tr("panel.info") || "Info"
                  outlined: true
                  onClicked: showFlatpakInfo(modelData)
                }
              }
            }
          }
        }
      }

      // Updates Tab
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: selectedTab === "updates"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true

            NButton {
              text: pluginApi?.tr("panel.updateAll") || "Update All"
              outlined: true
              onClicked: updateAllFlatpaks()
            }

            Item { Layout.fillWidth: true }
          }

          Repeater {
            id: updatesRepeater
            model: sortedUpdates

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || modelData.id || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.id || ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.version ? "v" + modelData.version : ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: pluginApi?.tr("panel.update") || "Update"
                  outlined: true
                  onClicked: updateFlatpak(modelData.id, modelData.name)
                }
              }
            }
          }

          NText {
            visible: !loading && updateableFlatpaks.length === 0
            text: pluginApi?.tr("panel.noUpdates") || "All flatpaks are up to date"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }
      }

      // Remotes Tab
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: selectedTab === "remotes"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NButton {
              text: pluginApi?.tr("remotes.flathub")
              outlined: !isRemoteEnabled("flathub")
              onClicked: toggleRemote("flathub")
            }
            NButton {
              text: pluginApi?.tr("remotes.flathubBeta")
              outlined: !isRemoteEnabled("flathub-beta")
              onClicked: toggleRemote("flathub-beta")
            }
            NButton {
              text: pluginApi?.tr("remotes.gnomeNightly")
              outlined: !isRemoteEnabled("gnome")
              onClicked: toggleRemote("gnome")
            }
            NButton {
              text: pluginApi?.tr("remotes.kde")
              outlined: !isRemoteEnabled("kde")
              onClicked: toggleRemote("kde")
            }
          }

          NText {
            text: pluginApi?.tr("panel.configuredRemotes")
            font.weight: Font.Bold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          Repeater {
            id: remotesRepeater
            model: remotes

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: modelData.url || ""
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }
              }
            }
          }

          NText {
            visible: remotes.length === 0 && !loading
            text: pluginApi?.tr("panel.noRemotes")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }
      }

      // Running Tab
      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: selectedTab === "running"

        ColumnLayout {
          width: parent.width
          spacing: Style.marginM

          Repeater {
            id: runningRepeater
            model: runningFlatpaks

            NBox {
              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + Style.marginM * 2
              radius: Style.radiusM

              RowLayout {
                id: rowLayout
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  margins: Style.marginM
                }
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 8
                  Layout.preferredHeight: 8
                  radius: 4
                  color: "#4CAF50"
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.name || modelData.id || ""
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                  }
                  NText {
                    text: pluginApi?.tr("panel.pid") + " " + modelData.pid
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeXS
                    Layout.fillWidth: true
                  }
                }

                NButton {
                  text: pluginApi?.tr("panel.kill") || "Kill"
                  outlined: true
                  onClicked: killFlatpak(modelData.pid, modelData.name)
                }
              }
            }
          }

          NText {
            visible: runningFlatpaks.length === 0 && !loading
            text: pluginApi?.tr("panel.noRunning") || "No running flatpaks"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }
      }

      // Empty states
      NText {
        visible: !loading && selectedTab === "installed" && sortedInstalled.length === 0
        text: pluginApi?.tr("panel.noInstalled") || "No installed flatpaks"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }

  function getScopeFlag() {
    var scope = pluginApi?.pluginSettings?.defaultScope || "user"
    return scope === "system" ? "--system" : "--user"
  }

  function isRemoteEnabled(remoteName) {
    var enabled = pluginApi?.pluginSettings?.enabledRemotes || ["flathub", "flathub-beta"]
    return enabled.indexOf(remoteName) !== -1
  }

  function toggleRemote(remoteName) {
    if (!pluginApi) return
    var enabled = pluginApi.pluginSettings.enabledRemotes || ["flathub", "flathub-beta"]
    var idx = enabled.indexOf(remoteName)
    if (idx !== -1) {
      enabled.splice(idx, 1)
    } else {
      enabled.push(remoteName)
    }
    pluginApi.pluginSettings.enabledRemotes = enabled
    pluginApi.saveSettings()
  }

  function refreshAll() {
    refreshInstalled()
    refreshRunning()
  }

  function refreshInstalled() {
    loading = true
    errorMessage = ""
    listInstalledProcess_out = ""
    var scope = getScopeFlag()
    listInstalledProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " list --app --columns=name,application,version,origin 2>&1"
    ]
    listInstalledProcess.running = true
  }

  function refreshRunning() {
    listRunningProcess_out = ""
    listRunningProcess.command = [
      "sh", "-c",
      "flatpak ps 2>&1"
    ]
    listRunningProcess.running = true
  }

  function checkForUpdates() {
    loading = true
    errorMessage = ""
    listUpdatesProcess_out = ""
    var scope = getScopeFlag()
    listUpdatesProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " list --app --upgrades --columns=name,application,version,origin 2>&1"
    ]
    listUpdatesProcess.running = true
  }

  function refreshRemotes() {
    listRemotesProcess_out = ""
    var scope = getScopeFlag()
    listRemotesProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " remote-list --columns=name,url 2>&1"
    ]
    listRemotesProcess.running = true
  }

  function parseInstalledList(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      allFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("ID") !== -1) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    allFlatpaks = result
    Logger.i("FlatpakPanel", "Parsed", result.length, "installed flatpaks")
  }

  function parseRunningList(raw) {
    if (!raw || raw.trim().length === 0) {
      runningFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 3) continue
      var parts = line.split(/\s+/)
      if (parts.length >= 3) {
        result.push({
          pid: parts[0],
          name: parts[1],
          id: parts[2]
        })
      }
    }
    runningFlatpaks = result
    Logger.i("FlatpakPanel", "Parsed", result.length, "running flatpaks")
  }

  function parseUpdatesList(raw) {
    loading = false
    if (!raw || raw.trim().length === 0) {
      updateableFlatpaks = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("ID") !== -1) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    updateableFlatpaks = result
    Logger.i("FlatpakPanel", "Parsed", result.length, "updateable flatpaks")
  }

  function parseRemotesList(raw) {
    if (!raw || raw.trim().length === 0) {
      remotes = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      if (line.indexOf("Name") !== -1 && line.indexOf("URL") !== -1) continue
      var parts = line.split(/\s+/)
      if (parts.length >= 2) {
        result.push({
          name: parts[0],
          url: parts.slice(1).join(" ")
        })
      }
    }
    remotes = result
    Logger.i("FlatpakPanel", "Parsed", result.length, "remotes")
  }

  function parseFlatpakLine(line) {
    var parts = line.split(/\t+/)
    if (parts.length < 2) {
      parts = line.split(/\s+/)
    }
    if (parts.length < 2) return null

    return {
      name: parts[0] || "",
      description: parts[1] || "",
      application: parts[2] || "",
      version: parts[3] || "",
      origin: parts[4] || ""
    }
  }

  function searchFlatpaks(query) {
    if (!query || query.length < 2) {
      searchResults = []
      return
    }
    loadingSearch = true
    searchProcess_out = ""
    var scope = getScopeFlag()
    searchProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " search '" + query.replace(/'/g, "'\\''") + "' 2>&1"
    ]
    searchProcess.running = true
  }

  function parseSearchResults(raw) {
    loadingSearch = false
    if (!raw || raw.trim().length === 0) {
      searchResults = []
      return
    }
    var lines = raw.split("\n")
    var result = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.length < 5) continue
      var flatpak = parseFlatpakLine(line)
      if (flatpak && flatpak.application) result.push(flatpak)
    }
    searchResults = result
    Logger.i("FlatpakPanel", "Parsed", result.length, "search results")
  }

  function loadBrowseRecommendations() {
    searchResults = allFlatpaks.slice(0, 20)
  }

  function showFlatpakInfo(flatpak) {
    ToastService.showNotice(flatpak.name + ": " + flatpak.application)
  }

  function runFlatpak(id, name) {
    root._actionFlatpak = name || id
    root._actionName = "run"
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " run '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function installFlatpak(id, name) {
    root._actionFlatpak = name || id
    root._actionName = "install"
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " install -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function uninstallFlatpak(id, name) {
    root._actionFlatpak = name || id
    root._actionName = "uninstall"
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " uninstall -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function updateFlatpak(id, name) {
    root._actionFlatpak = name || id
    root._actionName = "update"
    var scope = getScopeFlag()
    var escapedId = id.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " update -y '" + escapedId + "' 2>&1"
    ]
    actionProcess.running = true
  }

  function updateAllFlatpaks() {
    root._actionFlatpak = "all"
    root._actionName = "update"
    var scope = getScopeFlag()
    actionProcess.command = [
      "sh", "-c",
      "flatpak " + scope + " update -y 2>&1"
    ]
    actionProcess.running = true
  }

  function killFlatpak(pid, name) {
    root._actionFlatpak = name || pid
    root._actionName = "kill"
    var escapedPid = pid.replace(/'/g, "'\\''")
    actionProcess.command = [
      "sh", "-c",
      "flatpak kill '" + escapedPid + "' 2>&1"
    ]
    actionProcess.running = true
  }

  Process {
    id: appstreamUpdateProcess

    environment: Object.assign({}, Qt.application.environment)

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        if (pluginApi) {
          pluginApi.pluginSettings.appstreamUpdated = true
        }
        ToastService.showNotice("Appstream data updated")
      } else {
        ToastService.showError("Failed to update appstream data")
      }
    }
  }

  function updateAppstream() {
    ToastService.showNotice("Updating appstream data...")
    appstreamUpdateProcess.command = ["sh", "-c", "flatpak update --appstream 2>&1"]
    appstreamUpdateProcess.running = true
  }

  property var sortedInstalled: {
    if (!allFlatpaks) return []
    var result = allFlatpaks.slice()
    result.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") })
    return result
  }

  property var sortedUpdates: {
    if (!updateableFlatpaks) return []
    var result = updateableFlatpaks.slice()
    result.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") })
    return result
  }
}
