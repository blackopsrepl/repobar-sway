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
    property var selectedRepository: null
    property bool searchPanelOpen: false
    property string activeSearchQuery: ""
    property var searchData: searchAdapter.status ? ({
        status: searchAdapter.status,
        query: searchAdapter.query,
        selectedFullName: searchAdapter.selectedFullName,
        results: searchAdapter.results || [],
        error: searchAdapter.error
    }) : ({ status: "idle", query: "", selectedFullName: "", results: [], error: "" })
    property var searchResults: searchData.results || []

    component RepoActionButton: Button {
        id: actionButton

        property string iconName: "open"
        property string tooltip: ""
        property bool active: false
        property string iconColor: "#DDF7FF"
        property string accentColor: "#85E1FB"
        property string activeFillColor: "#1B3A40"
        property string disabledColor: "#4A557C"

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        implicitWidth: 34
        implicitHeight: 34
        padding: 0
        hoverEnabled: true

        ToolTip.delay: 350
        ToolTip.visible: actionButton.hovered && actionButton.tooltip.length > 0
        ToolTip.text: actionButton.tooltip
        Accessible.name: actionButton.tooltip
        Accessible.role: Accessible.Button

        background: Rectangle {
            radius: 4
            color: !actionButton.enabled ? "#101326" : actionButton.down ? "#223354" : actionButton.hovered ? "#18233C" : actionButton.active ? actionButton.activeFillColor : "#0F1324"
            border.width: 1
            border.color: !actionButton.enabled ? "#253057" : actionButton.active ? actionButton.accentColor : actionButton.hovered ? "#85E1FB" : "#253057"
        }

        contentItem: Item {
            implicitWidth: 34
            implicitHeight: 34

            Canvas {
                id: iconCanvas
                anchors.centerIn: parent
                width: 18
                height: 18

                Connections {
                    target: actionButton
                    function onIconNameChanged() { iconCanvas.requestPaint() }
                    function onActiveChanged() { iconCanvas.requestPaint() }
                    function onEnabledChanged() { iconCanvas.requestPaint() }
                    function onIconColorChanged() { iconCanvas.requestPaint() }
                    function onAccentColorChanged() { iconCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"

                    var stroke = actionButton.enabled ? (actionButton.active ? actionButton.accentColor : actionButton.iconColor) : actionButton.disabledColor
                    ctx.strokeStyle = stroke
                    ctx.fillStyle = actionButton.active ? actionButton.accentColor : "transparent"

                    if (actionButton.iconName === "open") {
                        ctx.strokeRect(3.5, 7.5, 7, 7)
                        ctx.beginPath()
                        ctx.moveTo(8.5, 9.5)
                        ctx.lineTo(14.3, 3.7)
                        ctx.moveTo(10.2, 3.7)
                        ctx.lineTo(14.3, 3.7)
                        ctx.lineTo(14.3, 7.8)
                        ctx.stroke()
                    } else if (actionButton.iconName === "read") {
                        ctx.beginPath()
                        ctx.moveTo(5, 3)
                        ctx.lineTo(11.5, 3)
                        ctx.lineTo(14, 5.5)
                        ctx.lineTo(14, 15)
                        ctx.lineTo(5, 15)
                        ctx.closePath()
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(11.5, 3)
                        ctx.lineTo(11.5, 5.5)
                        ctx.lineTo(14, 5.5)
                        ctx.moveTo(7, 8)
                        ctx.lineTo(12, 8)
                        ctx.moveTo(7, 11)
                        ctx.lineTo(12, 11)
                        ctx.stroke()
                    } else if (actionButton.iconName === "refresh") {
                        ctx.beginPath()
                        ctx.arc(9, 9, 5.4, 0.45, 4.85, false)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(5.1, 4.8)
                        ctx.lineTo(4.5, 8.1)
                        ctx.lineTo(7.7, 7.2)
                        ctx.moveTo(12.9, 13.2)
                        ctx.lineTo(13.5, 9.9)
                        ctx.lineTo(10.3, 10.8)
                        ctx.stroke()
                    } else if (actionButton.iconName === "pin" || actionButton.iconName === "pinFilled") {
                        ctx.beginPath()
                        ctx.moveTo(6, 3)
                        ctx.lineTo(12.2, 3)
                        ctx.lineTo(11, 6.3)
                        ctx.lineTo(14.5, 9.6)
                        ctx.lineTo(10.4, 9.8)
                        ctx.lineTo(9, 15.2)
                        ctx.lineTo(7.6, 9.8)
                        ctx.lineTo(3.5, 9.6)
                        ctx.lineTo(7, 6.3)
                        ctx.closePath()
                        if (actionButton.active || actionButton.iconName === "pinFilled") {
                            ctx.globalAlpha = actionButton.enabled ? 0.22 : 0.12
                            ctx.fill()
                            ctx.globalAlpha = 1
                        }
                        ctx.stroke()
                    } else if (actionButton.iconName === "hide") {
                        ctx.beginPath()
                        ctx.moveTo(2.5, 9)
                        ctx.bezierCurveTo(5.1, 5.8, 12.9, 5.8, 15.5, 9)
                        ctx.bezierCurveTo(12.9, 12.2, 5.1, 12.2, 2.5, 9)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(9, 9, 2.1, 0, Math.PI * 2, false)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(4, 14)
                        ctx.lineTo(14, 4)
                        ctx.stroke()
                    }
                }
            }
        }
    }

    component DragHandle: Item {
        id: handle

        property string tooltip: ""
        property string dragFullName: ""
        property bool active: dragArea.drag.active
        property string iconColor: "#DDF7FF"
        property string accentColor: "#F2C572"

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        implicitWidth: 34
        implicitHeight: 34

        ToolTip.delay: 350
        ToolTip.visible: dragArea.containsMouse && handle.tooltip.length > 0
        ToolTip.text: handle.tooltip
        Accessible.name: handle.tooltip
        Accessible.role: Accessible.Button

        Drag.active: dragArea.drag.active
        Drag.keys: ["repobar-pinned-repo"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: handle.active ? "#2E281B" : dragArea.containsMouse ? "#221F19" : "#0F1324"
            border.width: 1
            border.color: handle.active || dragArea.containsMouse ? handle.accentColor : "#253057"
        }

        Canvas {
            id: dragIcon
            anchors.centerIn: parent
            width: 18
            height: 18

            Connections {
                target: handle
                function onActiveChanged() { dragIcon.requestPaint() }
                function onIconColorChanged() { dragIcon.requestPaint() }
                function onAccentColorChanged() { dragIcon.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = handle.active ? handle.accentColor : handle.iconColor
                for (var row = 0; row < 3; row++) {
                    for (var column = 0; column < 2; column++) {
                        ctx.beginPath()
                        ctx.arc(6 + column * 6, 5 + row * 4, 1.35, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: handle
            onPressed: handle.z = 20
            onReleased: {
                handle.x = 0
                handle.y = 0
                handle.z = 0
            }
        }
    }

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
            root.searchPanelOpen = false
            return
        }
        root.activeSearchQuery = query
        root.searchPanelOpen = true
        runRepobar(["search", query, "--limit", "8"])
    }

    function clearSearchUi() {
        root.searchPanelOpen = false
        root.activeSearchQuery = ""
        repoInput.text = ""
    }

    function searchPanelVisible() {
        return root.searchPanelOpen && searchData.status !== "idle" && searchData.query === root.activeSearchQuery
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

    function heatmapColor(cell) {
        if (!cell) {
            return "#202848"
        }
        if (cell.empty) {
            return "#0B0C16"
        }
        if (cell.intensity >= 4) {
            return "#50F872"
        }
        if (cell.intensity === 3) {
            return "#4FE88F"
        }
        if (cell.intensity === 2) {
            return "#82FB9C"
        }
        if (cell.intensity === 1) {
            return "#253057"
        }
        return "#202848"
    }

    function accountHeatmapText() {
        var heatmap = viewData.accountHeatmap
        if (!heatmap || !heatmap.available) {
            return ""
        }
        var provider = root.providerActive("forgejo") ? "Forgejo" : "GitHub"
        return "Global " + provider + " activity  " + (heatmap.total || 0) + " contributions"
    }

    function accountHeatmapWeeks() {
        var heatmap = viewData.accountHeatmap
        if (!heatmap || !heatmap.available || !heatmap.weeks) {
            return []
        }
        return heatmap.weeks
    }

    function accountHeatmapRows() {
        var heatmap = viewData.accountHeatmap
        if (!heatmap || !heatmap.available || !heatmap.rows) {
            return []
        }
        return heatmap.rows
    }

    function accountHeatmapStats() {
        var heatmap = viewData.accountHeatmap
        if (!heatmap || !heatmap.available || !heatmap.stats) {
            return ({})
        }
        return heatmap.stats
    }

    function firstItems(items, limit) {
        var output = []
        if (!items) {
            return output
        }
        for (var index = 0; index < items.length && index < limit; index++) {
            output.push(items[index])
        }
        return output
    }

    function workItems(repo) {
        if (!repo) {
            return 0
        }
        return (repo.issues ? repo.issues.length : 0) + (repo.pulls ? repo.pulls.length : 0)
    }

    function workLabel(repo) {
        if (!repo) {
            return ""
        }
        return (repo.pulls ? repo.pulls.length : 0) + " PR  " + (repo.issues ? repo.issues.length : 0) + " issues"
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

    function movePinnedRepo(fullName, position) {
        var normalized = (fullName || "").toString().toLowerCase()
        if (normalized.length === 0) {
            return
        }
        runRepobar(["pin", "move", normalized, position.toString()])
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
        property int verticalMargin: 18
        implicitWidth: screen ? screen.width : 960
        implicitHeight: screen ? screen.height : 760
        color: "transparent"
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins {
            top: 0
            bottom: 0
            left: 0
            right: 0
        }
        onVisibleChanged: {
            if (visible) {
                root.searchPanelOpen = false
                root.activeSearchQuery = ""
                repoInput.forceActiveFocus()
            }
        }

        Shortcut {
            sequence: "Esc"
            context: Qt.WindowShortcut
            onActivated: root.closePanel()
        }

        Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: "#050711"
                opacity: 0.66
            }

            Rectangle {
                id: modalFrame
                anchors.centerIn: parent
                width: Math.min(960, Math.max(320, panel.width - 36))
                height: Math.min(panel.height - 16, Math.max(420, panel.height - (panel.verticalMargin * 2)))
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        visible: !!(viewData.accountHeatmap && viewData.accountHeatmap.available)
                        color: "#101326"
                        border.color: "#253057"
                        border.width: 1
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 6

                                Text {
                                    text: root.accountHeatmapText()
                                    color: "#9CF7C2"
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Flickable {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 74
                                    contentWidth: accountHeatmapGrid.implicitWidth
                                    contentHeight: accountHeatmapGrid.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    Column {
                                        id: accountHeatmapGrid
                                        spacing: 2

                                        Repeater {
                                            model: root.accountHeatmapRows()

                                            Row {
                                                property var rowData: modelData
                                                spacing: 2

                                                Repeater {
                                                    model: rowData.cells || []

                                                    Rectangle {
                                                        width: 8
                                                        height: 8
                                                        radius: 1
                                                        color: root.heatmapColor(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 220
                                Layout.fillHeight: true
                                visible: modalFrame.width >= 760
                                color: "#0B0C16"
                                border.color: "#253057"
                                border.width: 1
                                radius: 3

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Contribution summary"
                                        color: "#85E1FB"
                                        font.family: root.textFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        rowSpacing: 2
                                        columnSpacing: 8

                                        Text {
                                            text: "Active"
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: (root.accountHeatmapStats().activeDays || 0) + " days"
                                            color: "#DDF7FF"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "Streak"
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: (root.accountHeatmapStats().currentStreak || 0) + " days"
                                            color: "#DDF7FF"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "Best day"
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: root.accountHeatmapStats().bestDayText || "none"
                                            color: "#DDF7FF"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: "Peak"
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: (root.accountHeatmapStats().bestCount || 0) + " contributions"
                                            color: "#DDF7FF"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
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
                            onTextChanged: {
                                if (repoInput.text.trim().length === 0 || (root.activeSearchQuery.length > 0 && repoInput.text.trim() !== root.activeSearchQuery)) {
                                    root.searchPanelOpen = false
                                }
                            }
                            Keys.onEscapePressed: {
                                if (root.searchPanelOpen) {
                                    root.clearSearchUi()
                                } else {
                                    root.closePanel()
                                }
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
                    visible: root.searchPanelVisible()
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: root.searchStatusText()
                            color: searchData.status === "error" ? "#E06C75" : "#9CF7C2"
                            font.family: root.textFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Button {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: 64
                            text: "Clear"
                            onClicked: root.clearSearchUi()
                        }
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

                                RowLayout {
                                    Layout.preferredWidth: implicitWidth
                                    spacing: 6

                                    RepoActionButton {
                                        iconName: "open"
                                        tooltip: "Open repository"
                                        accentColor: "#85E1FB"
                                        onClicked: {
                                            root.runRepobar(["open", root.repoUrl(modelData)])
                                            root.clearSearchUi()
                                        }
                                    }
                                    RepoActionButton {
                                        iconName: root.isPinned(modelData.fullName) ? "pinFilled" : "pin"
                                        tooltip: root.isPinned(modelData.fullName) ? "Already pinned" : "Pin repository"
                                        active: root.isPinned(modelData.fullName)
                                        enabled: !root.isPinned(modelData.fullName)
                                        accentColor: "#9CF7C2"
                                        activeFillColor: "#14342F"
                                        onClicked: {
                                            root.runRepobar(["pin", modelData.fullName])
                                            root.clearSearchUi()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    visible: root.selectedRepository !== null
                    color: "#101326"
                    border.color: "#253057"
                    border.width: 1
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.selectedRepository ? (root.selectedRepository.fullName + "  " + root.workLabel(root.selectedRepository)) : ""
                                color: "#DDF7FF"
                                font.family: root.textFont
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Button {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 72
                                text: "Open"
                                enabled: root.selectedRepository !== null
                                onClicked: root.runRepobar(["open", root.repoUrl(root.selectedRepository)])
                            }
                            Button {
                                Layout.preferredHeight: 28
                                Layout.preferredWidth: 72
                                text: "Close"
                                onClicked: root.selectedRepository = null
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: readerColumn.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: readerColumn
                                width: parent.width
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.selectedRepository !== null && root.workItems(root.selectedRepository) === 0
                                    text: "No open issues or pull requests in the cached snapshot."
                                    color: "#6A6E95"
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.selectedRepository && root.selectedRepository.pulls && root.selectedRepository.pulls.length > 0
                                    text: "Pull requests"
                                    color: "#85E1FB"
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Repeater {
                                    model: (root.selectedRepository && root.selectedRepository.pulls) ? root.firstItems(root.selectedRepository.pulls, 3) : []

                                    ColumnLayout {
                                        width: readerColumn.width
                                        spacing: 3

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                text: "#" + modelData.number + " " + (modelData.draft ? "[draft] " : "") + modelData.title
                                                color: "#DDF7FF"
                                                font.family: root.textFont
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: "@" + modelData.author + "  " + modelData.updatedText
                                                color: "#6A6E95"
                                                font.family: root.textFont
                                                font.pixelSize: 10
                                                Layout.preferredWidth: 150
                                                elide: Text.ElideRight
                                            }

                                            Button {
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: 56
                                                text: "Open"
                                                enabled: (modelData.url || "").length > 0
                                                onClicked: root.runRepobar(["open", modelData.url])
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.body || "No description."
                                            color: "#8FA4D8"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: "#253057"
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.selectedRepository && root.selectedRepository.issues && root.selectedRepository.issues.length > 0
                                    text: "Issues"
                                    color: "#85E1FB"
                                    font.family: root.textFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Repeater {
                                    model: (root.selectedRepository && root.selectedRepository.issues) ? root.firstItems(root.selectedRepository.issues, 3) : []

                                    ColumnLayout {
                                        width: readerColumn.width
                                        spacing: 3

                                        RowLayout {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                Layout.fillWidth: true
                                                text: "#" + modelData.number + " " + modelData.title
                                                color: "#DDF7FF"
                                                font.family: root.textFont
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: "@" + modelData.author + "  " + modelData.updatedText
                                                color: "#6A6E95"
                                                font.family: root.textFont
                                                font.pixelSize: 10
                                                Layout.preferredWidth: 150
                                                elide: Text.ElideRight
                                            }

                                            Button {
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: 56
                                                text: "Open"
                                                enabled: (modelData.url || "").length > 0
                                                onClicked: root.runRepobar(["open", modelData.url])
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.body || "No description."
                                            color: "#8FA4D8"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            visible: modelData.labels && modelData.labels.length > 0
                                            text: "Labels: " + modelData.labels.join(", ")
                                            color: "#6A6E95"
                                            font.family: root.textFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: "#253057"
                                        }
                                    }
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
                                id: repoCard

                                property bool dropTarget: false
                                property string dragFullName: (modelData.fullName || "").toString().toLowerCase()
                                property int repoIndex: index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 196
                                color: dropTarget ? "#1D1A24" : "#141528"
                                border.color: dropTarget ? "#F2C572" : statusColor(modelData.status)
                                border.width: 1
                                radius: 4

                                DropArea {
                                    anchors.fill: parent
                                    enabled: modelData.pinned
                                    keys: ["repobar-pinned-repo"]
                                    onEntered: function(drag) {
                                        if (drag.source && drag.source.dragFullName !== repoCard.dragFullName) {
                                            repoCard.dropTarget = true
                                        }
                                    }
                                    onExited: repoCard.dropTarget = false
                                    onDropped: function(drop) {
                                        repoCard.dropTarget = false
                                        if (drop.source && drop.source.dragFullName !== repoCard.dragFullName) {
                                            root.movePinnedRepo(drop.source.dragFullName, repoCard.repoIndex)
                                        }
                                    }
                                }

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
                                            Layout.preferredWidth: modalFrame.width < 560 ? 108 : 136
                                            Layout.maximumWidth: 150
                                            elide: Text.ElideRight
                                        }

                                        Item {
                                            id: heatmapTrack
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 58
                                            Layout.preferredHeight: 18
                                            clip: true

                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2
                                                Repeater {
                                                    model: modelData.heatmap && modelData.heatmap.cells ? modelData.heatmap.cells : []
                                                    Rectangle {
                                                        width: 6
                                                        height: 14
                                                        radius: 1
                                                        color: root.heatmapColor(modelData)
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: repoActionStrip
                                            Layout.preferredWidth: implicitWidth
                                            spacing: 2

                                            DragHandle {
                                                visible: modelData.pinned
                                                tooltip: "Drag pinned repository"
                                                dragFullName: repoCard.dragFullName
                                            }

                                            RepoActionButton {
                                                iconName: "open"
                                                tooltip: "Open repository"
                                                accentColor: "#85E1FB"
                                                onClicked: runRepobar(["open", root.repoUrl(modelData)])
                                            }

                                            RepoActionButton {
                                                iconName: "read"
                                                tooltip: "Read work items"
                                                enabled: root.workItems(modelData) > 0
                                                accentColor: "#9CF7C2"
                                                onClicked: root.selectedRepository = modelData
                                            }

                                            RepoActionButton {
                                                iconName: "refresh"
                                                tooltip: "Refresh repositories"
                                                accentColor: "#85E1FB"
                                                onClicked: runRepobar(["refresh"])
                                            }

                                            RepoActionButton {
                                                iconName: modelData.pinned ? "pinFilled" : "pin"
                                                tooltip: modelData.pinned ? "Unpin repository" : "Pin repository"
                                                active: modelData.pinned
                                                accentColor: "#9CF7C2"
                                                activeFillColor: "#14342F"
                                                onClicked: runRepobar([modelData.pinned ? "unpin" : "pin", modelData.fullName])
                                            }

                                            RepoActionButton {
                                                iconName: "hide"
                                                tooltip: "Hide repository"
                                                accentColor: "#E06C75"
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
    }
}
