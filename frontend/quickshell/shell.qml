import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property string configPath: Quickshell.env("REPOBAR_CONFIG") || ((Quickshell.env("HOME") || "") + "/.repobar/config.json")
    property string stateDir: Quickshell.env("REPOBAR_STATE_DIR") || ((Quickshell.env("HOME") || "") + "/.local/state/repobar")
    property string repobarBin: Quickshell.env("REPOBAR_BIN") || "repobar"
    property string snapshotPath: stateDir + "/snapshot.json"
    property string uiPath: stateDir + "/ui.json"
    property string searchPath: stateDir + "/search.json"
    property string stateEventPath: stateDir + "/state-event.json"
    property string textFont: "Fira Code"

    property var viewData: snapshotAdapter.view && snapshotAdapter.view.summary ? snapshotAdapter.view : ({ summary: {}, chip: {}, repositories: [] })
    property var repositories: viewData.repositories || []
    property var searchData: searchAdapter.status ? ({
        status: searchAdapter.status,
        query: searchAdapter.query,
        selectedFullName: searchAdapter.selectedFullName,
        results: searchAdapter.results || [],
        error: searchAdapter.error
    }) : ({ status: "idle", query: "", selectedFullName: "", results: [], error: "" })
    property var searchResults: searchData.results || []

    function statusColor(status) {
        if (status === "error" || status === "ci-failing") {
            return "#E06C75"
        }
        if (status === "dirty" || status === "work") {
            return "#E5C07B"
        }
        if (status === "pending") {
            return "#85E1FB"
        }
        return "#82FB9C"
    }

    function runRepobar(args) {
        if (actionRunner.running) {
            actionRunner.signal(9)
            actionRunner.running = false
        }
        actionRunner.command = [root.repobarBin].concat(args).concat(["--config", root.configPath])
        actionRunner.running = true
    }

    function runSearch() {
        var query = repoInput.text.trim()
        if (query.length === 0) {
            return
        }
        runRepobar(["search", query, "--limit", "8"])
    }

    function closePanel() {
        runRepobar(["ui", "close"])
    }

    function reloadState() {
        snapshotFile.reload()
        uiFile.reload()
        searchFile.reload()
    }

    function heatmapText(repo) {
        if (repo.pending) {
            return "Refreshing..."
        }
        if (!repo.heatmap) {
            return "Activity heatmap"
        }
        return "Activity " + (repo.heatmap.total || 0) + " commits"
    }

    function providerActive(provider) {
        return (viewData.summary.provider || "github") === provider
    }

    function repoUrl(repo) {
        return repo.url || ("https://github.com/" + repo.fullName)
    }

    function isPinned(fullName) {
        var normalized = (fullName || "").toString().toLowerCase()
        for (var index = 0; index < root.repositories.length; index++) {
            var repo = root.repositories[index]
            if ((repo.fullName || "").toString().toLowerCase() === normalized && repo.pinned) {
                return true
            }
        }
        return false
    }

    function searchStatusText() {
        if (searchData.status === "loading") {
            return "Searching " + searchData.query + "..."
        }
        if (searchData.status === "error") {
            return searchData.error || "Search failed"
        }
        if (searchData.status === "ready" && searchResults.length === 0) {
            return "No repositories found for " + searchData.query
        }
        if (searchData.status === "ready") {
            return searchResults.length + " results for " + searchData.query
        }
        return ""
    }

    Process {
        id: actionRunner
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length) {
                    console.log(text.trim())
                }
            }
        }
    }

    FileView {
        id: stateEventFile
        path: root.stateEventPath
        watchChanges: true
        onFileChanged: root.reloadState()
    }

    FileView {
        id: snapshotFile
        path: root.snapshotPath
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: snapshotAdapter
            property string generatedAt: ""
            property var account: ({})
            property var repositories: []
            property var localRepositories: []
            property var view: ({})
        }
    }

    FileView {
        id: uiFile
        path: root.uiPath
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: uiAdapter
            property bool open: false
            property string focusRepository: ""
            property string requestedAt: ""
        }
    }

    FileView {
        id: searchFile
        path: root.searchPath
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: searchAdapter
            property string status: "idle"
            property string query: ""
            property string requestId: ""
            property string selectedFullName: ""
            property var results: []
            property string error: ""
            property string updatedAt: ""
        }
    }

    Component.onCompleted: root.reloadState()

    PanelWindow {
        id: panel
        visible: uiAdapter.open
        screen: Quickshell.screens.length ? Quickshell.screens[0] : null
        implicitWidth: Math.min(900, Math.max(420, (screen ? screen.width : 900) - 36))
        implicitHeight: Math.min(700, Math.max(420, (screen ? screen.height : 700) - 72))
        color: "transparent"
        focusable: true
        anchors {
            top: true
            right: true
        }
        margins {
            top: 36
            right: 12
        }
        onVisibleChanged: {
            if (visible) {
                repoInput.forceActiveFocus()
            }
        }

        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            onActivated: root.closePanel()
        }

        Rectangle {
            anchors.fill: parent
            color: "#0B0C16"
            border.color: "#82FB9C"
            border.width: 1
            radius: 4
            focus: true
            Keys.onEscapePressed: root.closePanel()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "RepoBar"
                                color: "#DDF7FF"
                                font.family: root.textFont
                                font.pixelSize: 22
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "@" + (viewData.summary.account || "not authenticated") + "  " + (viewData.summary.repoCount || 0) + " repos  " + (viewData.summary.openPulls || 0) + " PR  " + (viewData.summary.openIssues || 0) + " issues"
                                color: "#9CF7C2"
                                font.family: root.textFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        Button {
                            text: "GH"
                            enabled: !root.providerActive("github")
                            onClicked: runRepobar(["provider", "github"])
                        }
                        Button {
                            text: "FJ"
                            enabled: !root.providerActive("forgejo")
                            onClicked: runRepobar(["provider", "forgejo"])
                        }
                        Button {
                            text: "Refresh"
                            onClicked: runRepobar(["refresh"])
                        }
                        Button {
                            text: "Close"
                            onClicked: root.closePanel()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: repoInput
                            Layout.fillWidth: true
                            Layout.maximumWidth: 360
                            placeholderText: "owner/name or search"
                            font.family: root.textFont
                            onAccepted: root.runSearch()
                            Keys.onEscapePressed: root.closePanel()
                        }
                        Button {
                            text: "Pin"
                            enabled: repoInput.text.indexOf("/") > 0
                            onClicked: {
                                runRepobar(["pin", repoInput.text])
                                repoInput.text = ""
                            }
                        }
                        Button {
                            text: "Search"
                            onClicked: root.runSearch()
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#253057"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: searchData.status !== "idle"
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.searchStatusText()
                        color: searchData.status === "error" ? "#E06C75" : "#9CF7C2"
                        font.family: root.textFont
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: root.searchResults.slice(0, 6)

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            color: searchData.selectedFullName === modelData.fullName.toString().toLowerCase() ? "#202848" : "#141528"
                            border.color: searchData.selectedFullName === modelData.fullName.toString().toLowerCase() ? "#85E1FB" : "#253057"
                            border.width: 1
                            radius: 4

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.runRepobar(["search", "select", modelData.fullName])
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 34
                                    radius: 4
                                    color: "#0B0C16"
                                    border.color: "#253057"
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: modelData.ownerAvatarUrl || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: source.toString().length > 0
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.owner || "?").toString().slice(0, 1).toUpperCase()
                                        color: "#9CF7C2"
                                        font.family: root.textFont
                                        font.pixelSize: 13
                                        font.bold: true
                                        visible: !(modelData.ownerAvatarUrl || "")
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.fullName || ""
                                        color: "#DDF7FF"
                                        font.family: root.textFont
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description || "No description"
                                        color: "#8FA4D8"
                                        font.family: root.textFont
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: "Stars " + ((modelData.stats && modelData.stats.stars) || 0)
                                        color: "#6A6E95"
                                        font.family: root.textFont
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                Button {
                                    Layout.preferredWidth: 70
                                    text: "Open"
                                    onClicked: root.runRepobar(["open", root.repoUrl(modelData)])
                                }
                                Button {
                                    Layout.preferredWidth: 70
                                    text: root.isPinned(modelData.fullName) ? "Pinned" : "Pin"
                                    enabled: !root.isPinned(modelData.fullName)
                                    onClicked: root.runRepobar(["pin", modelData.fullName])
                                }
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: repoColumn.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: repoColumn
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: repositories

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 196
                                color: "#141528"
                                border.color: statusColor(modelData.status)
                                border.width: 1
                                radius: 4

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 12

                                        Rectangle {
                                            width: 8
                                            Layout.fillHeight: true
                                            radius: 2
                                            color: statusColor(modelData.status)
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 42
                                            Layout.preferredHeight: 42
                                            radius: 4
                                            color: "#0B0C16"
                                            border.color: "#253057"
                                            border.width: 1
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                source: modelData.ownerAvatarUrl || ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                visible: source.toString().length > 0
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: (modelData.owner || "?").toString().slice(0, 1).toUpperCase()
                                                color: "#9CF7C2"
                                                font.family: root.textFont
                                                font.pixelSize: 16
                                                font.bold: true
                                                visible: !(modelData.ownerAvatarUrl || "")
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Text {
                                                text: modelData.fullName || ""
                                                color: "#DDF7FF"
                                                font.family: root.textFont
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                            Text {
                                                text: modelData.pending ? "Pending refresh" : (modelData.description || "")
                                                color: modelData.pending ? "#85E1FB" : "#8FA4D8"
                                                font.family: root.textFont
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: "CI " + (modelData.ciStatus || "unknown") + "  PR " + (modelData.openPulls || 0) + "  Issues " + (modelData.openIssues || 0) + "  Stars " + (modelData.stars || 0) + "  Updated " + (modelData.pushedText || "unknown")
                                                color: "#9CF7C2"
                                                font.family: root.textFont
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: modelData.local ? ("Local " + modelData.local.branch + "  ahead " + modelData.local.ahead + " behind " + modelData.local.behind + " dirty " + modelData.local.dirtyCount) : "No matched local checkout"
                                                color: modelData.local && modelData.local.dirty ? "#E5C07B" : "#6A6E95"
                                                font.family: root.textFont
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: (modelData.latestRelease ? ("Release " + modelData.latestRelease.tag + "  ") : "") + (modelData.latestActivity ? modelData.latestActivity.title : "No recent activity")
                                                color: "#85E1FB"
                                                font.family: root.textFont
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 38
                                        spacing: 8

                                        Text {
                                            text: heatmapText(modelData)
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            Layout.preferredWidth: 150
                                            Layout.maximumWidth: 180
                                            elide: Text.ElideRight
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Repeater {
                                                model: modelData.heatmap && modelData.heatmap.cells ? modelData.heatmap.cells : []
                                                Rectangle {
                                                    width: 6
                                                    height: 14
                                                    radius: 1
                                                    color: modelData.intensity >= 4 ? "#50F872" : modelData.intensity === 3 ? "#4FE88F" : modelData.intensity === 2 ? "#82FB9C" : modelData.intensity === 1 ? "#253057" : "#202848"
                                                }
                                            }
                                        }

                                        Button {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: 78
                                            text: "Open"
                                            onClicked: runRepobar(["open", root.repoUrl(modelData)])
                                        }
                                        Button {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: 86
                                            text: "Refresh"
                                            onClicked: runRepobar(["refresh"])
                                        }
                                        Button {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: 68
                                            text: modelData.pinned ? "Unpin" : "Pin"
                                            onClicked: runRepobar([modelData.pinned ? "unpin" : "pin", modelData.fullName])
                                        }
                                        Button {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: 72
                                            text: "Hide"
                                            onClicked: runRepobar(["hide", modelData.fullName])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
