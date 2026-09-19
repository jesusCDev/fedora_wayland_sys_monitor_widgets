import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root
    preferredRepresentation: Plasmoid.compactRepresentation

    // Same live job feed the notification popup uses (Dolphin copy/move,
    // KDE downloads, browser downloads via Plasma Browser Integration)
    NotificationManager.Notifications {
        id: jobs
        showJobs: true
        showNotifications: false
        showExpired: false
        showDismissed: true  // job keeps showing here even if its notification was dismissed
    }

    readonly property bool hasJobs: jobs.activeJobsCount > 0

    // Vanish from the panel entirely when nothing is transferring
    Plasmoid.status: hasJobs || root.expanded
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.HiddenStatus

    // Suppress the built-in tooltip; we anchor our own styled one
    toolTipMainText: ""
    toolTipSubText: ""

    property bool hoverJobs: false
    property Item panelAnchor: null

    // Panel font scaling: track panel thickness, ~10pt at the default 40px
    property real panelHeight: 0
    readonly property real panelPt: panelHeight > 0
        ? Math.max(10, Math.round(panelHeight * 0.33 * 2) / 2) : 10

    readonly property color accent: "#FFD98E"
    readonly property color track: "#33888888"
    readonly property color dim: "#888888"

    // Panel shows only the lead job: the running one with the highest
    // percentage (ties keep the lowest row index).
    property int leadIndex: -1

    function recomputeLead() {
        var N = NotificationManager.Notifications
        var best = -1, bestPct = -1
        for (var i = 0; i < jobs.count; i++) {
            var ix = jobs.index(i, 0)
            if (jobs.data(ix, N.JobStateRole) === N.JobStateStopped) continue
            var pct = jobs.data(ix, N.PercentageRole) || 0
            if (pct > bestPct) { bestPct = pct; best = i }
        }
        leadIndex = best
    }
    Timer { id: leadTimer; interval: 0; onTriggered: root.recomputeLead() }
    Connections {
        target: jobs
        function onCountChanged() { leadTimer.restart() }
        function onDataChanged() { leadTimer.restart() }
        function onModelReset() { leadTimer.restart() }
        function onLayoutChanged() { leadTimer.restart() }
        function onRowsRemoved() { leadTimer.restart() }
    }

    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB"
        if (b >= 1024) return (b / 1024).toFixed(0) + " KB"
        return b + " B"
    }

    function fmtSpeed(bps) {
        return bps > 0 ? fmtBytes(bps) + "/s" : ""
    }

    function fmtEta(job) {
        if (!job || job.speed <= 0 || job.totalBytes <= 0) return ""
        var s = Math.round((job.totalBytes - job.processedBytes) / job.speed)
        if (s < 0) return ""
        var m = Math.floor(s / 60)
        if (m >= 60) return Math.floor(m / 60) + "h " + (m % 60) + "m left"
        if (m > 0) return m + "m " + (s % 60) + "s left"
        return s + "s left"
    }

    // ── Hover tooltip ─────────────────────────────────────────
    PlasmaCore.Dialog {
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.ToolTip
        location: Plasmoid.location
        visualParent: root.panelAnchor
        visible: root.hoverJobs && root.panelAnchor !== null && !root.expanded

        mainItem: Item {
            implicitWidth: ttFrame.implicitWidth
            implicitHeight: ttFrame.implicitHeight

            Rectangle {
                id: ttFrame
                implicitWidth: ttCol.implicitWidth + 32
                implicitHeight: ttCol.implicitHeight + 28
                color: "transparent"
                border.color: "#30FFFFFF"
                border.width: 1
                radius: 8

                ColumnLayout {
                    id: ttCol
                    x: 16
                    y: 14
                    spacing: 6

                    Text {
                        font.bold: true
                        font.pointSize: 11
                        color: "#FFFFFF"
                        text: root.hasJobs
                            ? (jobs.activeJobsCount === 1 ? "1 transfer" : jobs.activeJobsCount + " transfers")
                            : "No active transfers"
                    }

                    Repeater {
                        model: jobs
                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            visible: model.jobState !== NotificationManager.Notifications.JobStateStopped

                            readonly property var job: model.jobDetails
                            readonly property bool paused: model.jobState === NotificationManager.Notifications.JobStateSuspended

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: (model.percentage || 0) + "%"
                                    color: root.accent
                                    font.pointSize: 10
                                    font.bold: true
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    text: model.summary || "Transfer"
                                    color: "#FFFFFF"
                                    font.pointSize: 10
                                    textFormat: Text.PlainText
                                    elide: Text.ElideMiddle
                                    Layout.maximumWidth: 360
                                }
                            }

                            Text {
                                visible: text !== ""
                                color: root.dim
                                font.pointSize: 9
                                textFormat: Text.PlainText
                                text: {
                                    if (!job) return ""
                                    var parts = []
                                    if (paused) parts.push("paused")
                                    else if (job.speed > 0) parts.push(root.fmtSpeed(job.speed))
                                    if (job.totalBytes > 0)
                                        parts.push(root.fmtBytes(job.processedBytes) + " / " + root.fmtBytes(job.totalBytes))
                                    var eta = paused ? "" : root.fmtEta(job)
                                    if (eta) parts.push(eta)
                                    var dest = job.descriptionValue2 || job.descriptionValue1
                                    if (dest) parts.push(dest)
                                    return parts.join("   ·   ")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Panel: lead job bar, others fold into "+N" ──────────────
    compactRepresentation: Item {
        id: compactRoot
        onHeightChanged: if (height > 0) root.panelHeight = height
        Layout.preferredWidth: barsRow.width
        Layout.minimumWidth: barsRow.width
        Layout.maximumWidth: barsRow.width
        Component.onCompleted: root.panelAnchor = compactRoot

        Row {
            id: barsRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: jobs
                delegate: Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    // Only the lead job's row shows in the panel; leadIndex is
                    // -1 when no non-stopped job exists, so this already
                    // excludes stopped/finished jobs.
                    visible: index === root.leadIndex

                    Rectangle {
                        width: Math.round(46 * root.panelPt / 10)
                        height: Math.max(5, Math.round(root.panelPt / 2))
                        radius: height / 2
                        color: root.track
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: Math.max(3, parent.width * Math.min(100, model.percentage || 0) / 100)
                            height: parent.height
                            radius: parent.radius
                            color: model.jobState === NotificationManager.Notifications.JobStateSuspended
                                ? root.dim : root.accent
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                    Text {
                        text: (model.percentage || 0) + "%"
                        color: root.accent
                        font.pointSize: root.panelPt
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: jobs.activeJobsCount > 1
                        text: "+" + (jobs.activeJobsCount - 1)
                        color: root.dim
                        font.pointSize: root.panelPt
                        font.bold: false
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            // top 60% of panel only: overshooting a Chrome tab into the panel must not pop the tip
            onPositionChanged: function(m) {
                var f = mapToItem(null, 0, m.y).y / Window.height
                if (Plasmoid.location === PlasmaCore.Types.BottomEdge ? f > 0.4 : f < 0.6) root.hoverJobs = true
            }
            onExited: root.hoverJobs = false
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Popup: full detail per job ──────────────────────────────
    fullRepresentation: Item {
        Layout.preferredWidth: 400
        Layout.preferredHeight: popupCol.implicitHeight + 36
        Layout.minimumWidth: 360
        Layout.minimumHeight: popupCol.implicitHeight + 36

        ColumnLayout {
            id: popupCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Text {
                text: root.hasJobs
                    ? (jobs.activeJobsCount === 1 ? "1 transfer" : jobs.activeJobsCount + " transfers")
                    : "No active transfers"
                color: "#FFFFFF"
                font.pointSize: 12
                font.bold: true
            }

            Repeater {
                model: jobs
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: model.jobState !== NotificationManager.Notifications.JobStateStopped

                    readonly property var job: model.jobDetails
                    readonly property bool paused: model.jobState === NotificationManager.Notifications.JobStateSuspended

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: model.summary || "Transfer"
                            color: "#FFFFFF"
                            font.pointSize: 11
                            elide: Text.ElideMiddle
                        }
                        Text {
                            text: (model.percentage || 0) + "%"
                            color: root.accent
                            font.pointSize: 11
                            font.bold: true
                        }
                    }

                    // Destination file/folder
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: job && job.descriptionValue2 ? job.descriptionValue2
                            : (job && job.descriptionValue1 ? job.descriptionValue1 : "")
                        color: root.dim
                        font.pointSize: 9
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 7
                        radius: 3.5
                        color: root.track
                        Rectangle {
                            width: Math.max(4, parent.width * Math.min(100, model.percentage || 0) / 100)
                            height: parent.height
                            radius: parent.radius
                            color: parent.parent.paused ? root.dim : root.accent
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!job) return ""
                                var parts = []
                                if (paused) parts.push("paused")
                                else if (job.speed > 0) parts.push(root.fmtSpeed(job.speed))
                                if (job.totalBytes > 0)
                                    parts.push(root.fmtBytes(job.processedBytes) + " / " + root.fmtBytes(job.totalBytes))
                                var eta = paused ? "" : root.fmtEta(job)
                                if (eta) parts.push(eta)
                                return parts.join("   ·   ")
                            }
                            color: root.dim
                            font.pointSize: 9
                            elide: Text.ElideRight
                        }

                        PlasmaComponents.ToolButton {
                            visible: model.suspendable
                            icon.name: parent.parent.paused ? "media-playback-start" : "media-playback-pause"
                            display: PlasmaComponents.AbstractButton.IconOnly
                            onClicked: parent.parent.paused
                                ? jobs.resumeJob(jobs.index(index, 0))
                                : jobs.suspendJob(jobs.index(index, 0))
                        }
                        PlasmaComponents.ToolButton {
                            visible: model.killable
                            icon.name: "dialog-cancel"
                            display: PlasmaComponents.AbstractButton.IconOnly
                            onClicked: jobs.killJob(jobs.index(index, 0))
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: index < jobs.activeJobsCount - 1
                        height: 1
                        color: "#22888888"
                    }
                }
            }
        }
    }
}
