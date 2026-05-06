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
    property string stateEventPath: stateDir + "/state-event.json"
    property string textFont: "Fira Code"

    property var viewData: snapshotAdapter.view && snapshotAdapter.view.summary ? snapshotAdapter.view : ({ summary: {}, chip: {}, repositories: [] })
    property var repositories: viewData.repositories || []
    property var searchResults: []

    function statusColor(status) {
        if (status === "error" || status === "ci-failing") {
            return "#E06C75"
        }
        if (status === "dirty" || status === "work") {
            return "#E5C07B"
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
        if (repoInput.text.trim().length === 0) {
            root.searchResults = []
            return
        }
        if (searchRunner.running) {
            searchRunner.signal(9)
            searchRunner.running = false
        }
        searchRunner.command = [root.repobarBin, "search", repoInput.text, "--json", "--config", root.configPath]
        searchRunner.running = true
    }

    function reloadState() {
        snapshotFile.reload()
        uiFile.reload()
    }

    function trafficText(repo) {
        if (!repo.traffic) {
            return "Traffic unavailable"
        }
        return "Views " + (repo.traffic.uniqueViews || 0) + " unique  Clones " + (repo.traffic.uniqueClones || 0) + " unique"
    }

    function providerActive(provider) {
        return (viewData.summary.provider || "github") === provider
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

    Process {
        id: searchRunner
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.searchResults = JSON.parse(text)
                } catch (error) {
                    root.searchResults = []
                    console.log(error)
                }
            }
        }
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
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: uiAdapter
            property bool open: false
            property string focusRepository: ""
            property string requestedAt: ""
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

        Rectangle {
            anchors.fill: parent
            color: "#0B0C16"
            border.color: "#82FB9C"
            border.width: 1
            radius: 4

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
                            onClicked: uiAdapter.open = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: repoInput
                            Layout.fillWidth: true
                            Layout.maximumWidth: 320
                            placeholderText: "owner/name"
                            font.family: root.textFont
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
                            onClicked: runSearch()
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

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.searchResults.length > 0
                    spacing: 8

                    Repeater {
                        model: root.searchResults.slice(0, 3)
                        Button {
                            Layout.maximumWidth: 260
                            text: modelData.fullName
                            font.family: root.textFont
                            onClicked: {
                                runRepobar(["pin", modelData.fullName])
                                repoInput.text = ""
                                root.searchResults = []
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
                                                text: modelData.description || ""
                                                color: "#8FA4D8"
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
	                                            text: trafficText(modelData)
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
	                                            onClicked: runRepobar(["open", modelData.url || ("https://github.com/" + modelData.fullName)])
	                                        }
	                                        Button {
                                            Layout.preferredHeight: 30
                                            Layout.preferredWidth: 86
	                                            text: "Refresh"
	                                            onClicked: runRepobar(["repo", modelData.fullName])
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
