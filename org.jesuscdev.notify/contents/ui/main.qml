import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as PlasmaSupport
import org.kde.notificationmanager as NotificationManager
import "util.js" as U

PlasmoidItem {
    id: root
    preferredRepresentation: Plasmoid.compactRepresentation

    // ── Config ────────────────────────────────────────────────
    readonly property int historyLimit: Plasmoid.configuration.historyLimit
    readonly property bool readOnClose: Plasmoid.configuration.readOnClose
    readonly property bool chipsEnabled: Plasmoid.configuration.chipsEnabled
    readonly property string systemApps: Plasmoid.configuration.systemApps
    readonly property string groupPatterns: Plasmoid.configuration.groupPatterns
    readonly property bool logEnabled: Plasmoid.configuration.logEnabled

    // ── Colors ────────────────────────────────────────────────
    readonly property string colorOff: "#8A8A8A"
    readonly property string colorOn: "#FFFFFF"
    readonly property string colorDim: "#B0B0B0"
    readonly property string colorRead: "#8A8A8A"
    readonly property string colorCrit: "#EF5350"
    readonly property string colorAccent: "#4FC3F7"

    // ── Panel scaling (same recipe as sysmonitor) ─────────────
    property real panelHeight: 0
    readonly property real panelPt: panelHeight > 0
        ? Math.max(10, Math.round(panelHeight * 0.33 * 2) / 2) : 10

    // ── State ─────────────────────────────────────────────────
    property bool hoverBell: false
    property Item panelAnchor: null
    property Item flashRow: null      // row currently showing "copied"
    property int copySeq: 0           // keeps every copy command a distinct DataSource key
    property int logSeq: 0            // same for log commands; a burst inside one millisecond must not coalesce
    property real now: Date.now()     // bumped by a timer so relTime() rebinds
    property int unread: 0
    property int critUnread: 0
    property var secCount: [0, 0, 0]  // [personal, system, critical]
    property var secUnread: [0, 0, 0]
    property int rev: 0               // bumped on every recount; row bindings read it to refresh group lookups
    property var openGroups: ({})     // group keys unfolded by double-click
    function toggleGroup(key) {
        var o = Object.assign({}, openGroups)
        if (o[key]) delete o[key]; else o[key] = true
        openGroups = o
    }

    // System section = app name / desktop entry / notifyrc name matches the
    // user's regex. A broken regex matches nothing rather than breaking the popup.
    readonly property var systemRe: { try { return new RegExp(systemApps, "i") } catch (e) { return /$^/ } }
    onSystemAppsChanged: recountTimer.restart()
    // Critical urgency outranks the regex: those rows form the top section.
    function rowSection(app, entry, rc, urgency) {
        if (urgency === NotificationManager.Notifications.CriticalUrgency) return 2
        return systemRe.test([app, entry, rc].join(" ")) ? 1 : 0
    }
    function sectionOf(ix) {
        var N = NotificationManager.Notifications
        return rowSection(hist.data(ix, N.ApplicationNameRole), hist.data(ix, N.DesktopEntryRole), hist.data(ix, N.NotifyRcNameRole), hist.data(ix, N.UrgencyRole))
    }

    // Group rules: comma-separated regexes matched against app + summary. A hit
    // folds rows from any app (Claude via notify-send and via Chrome) into one
    // group named after the rule; misses group by app + summary. Section is
    // part of the key so a critical row never folds under a normal head.
    readonly property var groupRules: groupPatterns.split(",").map(function(r) { return r.trim() }).filter(function(r) { return r })
        .map(function(r) { try { return { name: r.charAt(0).toUpperCase() + r.slice(1), re: new RegExp(r, "i") } } catch (e) { return null } })
        .filter(function(r) { return r })
    onGroupPatternsChanged: recountTimer.restart()
    function groupOf(app, summary) {
        var t = (app || "") + " " + (summary || "")
        for (var i = 0; i < groupRules.length; i++) if (groupRules[i].re.test(t)) return groupRules[i].name
        return ""
    }
    function keyOf(sec, app, summary) { return sec + "\u001f" + (groupOf(app, summary) || (app || "") + "\u001f" + (summary || "")) }

    // KDE's rule (Notifications::updateCount): the read flag — set only when
    // the stock toast was shown — or older than lastRead. ReadRole alone is
    // not it; under fullscreen inhibition the flag never gets set.
    function seen(read, updated, created) {
        var d = updated && !isNaN(updated) ? updated : created
        return read || d <= hist.lastRead
    }
    function seenAt(ix) {
        var N = NotificationManager.Notifications
        return seen(hist.data(ix, N.ReadRole), hist.data(ix, N.UpdatedRole), hist.data(ix, N.CreatedRole))
    }

    // KDE's unreadNotificationsCount skips every non-expired row (critical
    // notifications never expire), so count unread/critical ourselves.
    function recount() {
        var u = 0, c = 0, n = [0, 0, 0], nu = [0, 0, 0], N = NotificationManager.Notifications
        for (var i = 0; i < hist.count; i++) {
            var ix = hist.index(i, 0), t = sectionOf(ix)
            n[t]++
            if (seenAt(ix)) continue
            u++
            nu[t]++
            if (hist.data(ix, N.UrgencyRole) === N.CriticalUrgency) c++
        }
        unread = u
        critUnread = c
        secCount = n
        secUnread = nu
        rev++
    }

    // Grouping: rows with the same app + summary ("Claude Code / Task finished"
    // ×12) fold into their newest one, which shows "+N" and dismisses the lot.
    // ponytail: linear scans per row over ≤ historyLimit rows; index the keys if the limit ever grows big.
    function rowKey(i) {
        var N = NotificationManager.Notifications, ix = hist.index(i, 0)
        return keyOf(sectionOf(ix), hist.data(ix, N.ApplicationNameRole), hist.data(ix, N.SummaryRole))
    }
    function firstWithKey(key) { for (var i = 0; i < hist.count; i++) if (rowKey(i) === key) return i; return -1 }
    function countKey(key) { var n = 0; for (var i = 0; i < hist.count; i++) if (rowKey(i) === key) n++; return n }
    function closeKey(key) { for (var i = hist.count - 1; i >= 0; i--) if (rowKey(i) === key) hist.close(hist.index(i, 0)) }
    // Older twins of the head at `head`, rendered inside that row when unfolded.
    function membersOf(key, head) {
        var N = NotificationManager.Notifications, out = []
        for (var i = head + 1; i < hist.count; i++) {
            if (rowKey(i) !== key) continue
            var ix = hist.index(i, 0)
            out.push({ idx: i, created: hist.data(ix, N.CreatedRole), summary: U.stripHtml(hist.data(ix, N.SummaryRole) || ""),
                       body: U.stripHtml(hist.data(ix, N.BodyRole) || ""), seen: seenAt(ix) })
        }
        return out
    }
    Timer { id: recountTimer; interval: 0; onTriggered: root.recount() }

    // ── Log: one TSV line per notification, for later questions ──────
    // time · app · desktop entry · notifyrc name · urgency · summary · body.
    // Bodies included (codes, messages): file and dir are created 0600/0700 in
    // the user's state dir, and the toggle lives in the config page.
    // flock serialises appends and the 3000→2000-line trim across bursts.
    function logRow(i) {
        if (!logEnabled) return
        var N = NotificationManager.Notifications, ix = hist.index(i, 0)
        var f = [new Date().toISOString(), hist.data(ix, N.ApplicationNameRole), hist.data(ix, N.DesktopEntryRole), hist.data(ix, N.NotifyRcNameRole),
                 hist.data(ix, N.UrgencyRole), U.stripHtml(hist.data(ix, N.SummaryRole) || ""), U.stripHtml(hist.data(ix, N.BodyRole) || "")]
        var line = f.map(function(x) { return String(x === undefined || x === null ? "" : x).replace(/[\t\r\n]+/g, " ") }).join("\t")
        // Paths stay shell variables, double-quoted at every use: a state dir with spaces must not break the log.
        fire('umask 077; d="${XDG_STATE_HOME:-$HOME/.local/state}"; lp="$d/notify-inline.log"; mkdir -p "$d" && exec 9>>"$lp.lock" && flock 9'
            + ' && printf \'%s\\n\' ' + U.shQuote(line) + ' >> "$lp"'
            + ' && [ "$(wc -l < "$lp")" -gt 3000 ] && tail -n 2000 "$lp" > "$lp.tmp.$$" && mv "$lp.tmp.$$" "$lp" #' + (++logSeq))
    }
    Connections {
        target: hist
        function onRowsInserted(parent, first, last) { for (var i = first; i <= last; i++) root.logRow(i) }
    }
    Connections {
        target: hist
        function onCountChanged() { recountTimer.restart() }
        function onDataChanged() { recountTimer.restart() }
        function onLastReadChanged() { recountTimer.restart() }
        function onModelReset() { recountTimer.restart() }
        function onLayoutChanged() { recountTimer.restart() }
    }

    // Suppress the built-in tooltip; we anchor our own styled one
    toolTipMainText: ""
    toolTipSubText: ""

    // ── Models: same history the stock applet reads ───────────
    NotificationManager.Settings { id: nmSettings }

    // Honor per-app "show in history" choices from the KCM, but not the distro
    // default that hides "@other" (every notification without a desktop-entry
    // hint: notify-send, scripts, CLI tools) — those are the ones worth keeping.
    function historyBlacklist() {
        var src = nmSettings.historyBlacklistedApplications, out = []
        for (var i = 0; i < src.length; i++) if (src[i] !== "@other") out.push(src[i])
        return out
    }

    NotificationManager.Notifications {
        id: hist
        showExpired: true
        showDismissed: true
        showJobs: false
        showAddedDuringInhibition: true   // history exists for exactly the ones you missed (fullscreen/DND)
        limit: root.historyLimit
        urgencies: NotificationManager.Notifications.LowUrgency | NotificationManager.Notifications.NormalUrgency | NotificationManager.Notifications.CriticalUrgency
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        blacklistedDesktopEntries: root.historyBlacklist()
        blacklistedNotifyRcNames: nmSettings.historyBlacklistedServices
    }

    // lastRead is process-wide (shared NotificationsModel): closing either
    // bell's popup marks everything read for both. undefined = now.
    onExpandedChanged: if (!root.expanded && readOnClose) hist.lastRead = undefined

    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() }
    Timer { id: flashTimer; interval: 900; onTriggered: root.flashRow = null }

    // ── Helpers (pure ones live in util.js, shared with the self-check) ──
    function copyText(s, rowItem) {
        if (!s) return
        fire(U.copyCmd(s, ++copySeq))
        flashRow = rowItem
        flashTimer.restart()
    }

    // Ctrl+click: the notification's own action if it has one, else its first link
    function openRow(i, chips) {
        var ix = hist.index(i, 0), N = NotificationManager.Notifications
        if (hist.data(ix, N.HasDefaultActionRole)) { hist.invokeDefaultAction(ix, N.None); return }
        for (var k = 0; k < chips.length; k++) if (openChip(chips[k])) return
    }
    function openChip(chip) {
        var v = chip.value
        if (/^https?:\/\//.test(v)) { fire("xdg-open " + U.shQuote(v) + " >/dev/null 2>&1 &"); return true }
        if (v.indexOf("@") > 0) { fire("xdg-open " + U.shQuote("mailto:" + v) + " >/dev/null 2>&1 &"); return true }
        return false
    }

    // ── Fire-and-forget shell ─────────────────────────────────
    function fire(cmd) { fireSource.connectSource(cmd) }
    function launchApp(cmd) { fire("sh -c '" + cmd + " &'") }

    PlasmaSupport.DataSource {
        id: fireSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) disconnectSource(source)
        }
    }

    // close() drops history rows and dismisses active ones (criticals never
    // expire), so one loop covers both.
    function clearAll() {
        for (var i = hist.count - 1; i >= 0; i--) hist.close(hist.index(i, 0))
    }
    // One section, folded twins included: sectionOf() sees every row, head or not.
    // Pin the targets as persistent indexes first, then close, so a removal
    // mid-loop cannot shift what is left.
    function clearSection(sec) {
        var targets = []
        for (var i = 0; i < hist.count; i++) {
            var ix = hist.index(i, 0)
            if (sectionOf(ix) === sec) targets.push(hist.makePersistentModelIndex(ix))
        }
        targets.forEach(function(p) { hist.close(p) })
    }

    // Drawn ×: a text glyph read as a letter. 20px hit box, hover ring.
    component CloseButton: Item {
        signal clicked()
        implicitWidth: 20
        implicitHeight: 20
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: xMa.containsMouse ? "#30FFFFFF" : "transparent"
        }
        Rectangle { anchors.centerIn: parent; width: 11; height: 2; radius: 1; rotation: 45; color: xMa.containsMouse ? root.colorOn : root.colorDim }
        Rectangle { anchors.centerIn: parent; width: 11; height: 2; radius: 1; rotation: -45; color: xMa.containsMouse ? root.colorOn : root.colorDim }
        MouseArea {
            id: xMa
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // Text link: footer "clear all" and section "clear". 6px of click slop around the text.
    component TextButton: Text {
        signal clicked()
        font.pointSize: 9.5
        color: tbMa.containsMouse ? root.colorAccent : root.colorDim
        Accessible.role: Accessible.Button
        Accessible.onPressAction: clicked()
        MouseArea {
            id: tbMa
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // ── Panel icon ────────────────────────────────────────────
    // 1.8×: the outline bell reads smaller than sysmonitor's filled icons at their 1.3×
    readonly property int panelIconPx: Math.round(panelPt * 1.8)
    readonly property string bellFile: critUnread > 0 ? "bell-warn.png" : (unread > 0 ? "bell.png" : "bell-dim.png")

    // ── Hover tooltip ─────────────────────────────────────────
    PlasmaCore.Dialog {
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.ToolTip
        location: Plasmoid.location
        visualParent: root.panelAnchor
        visible: root.hoverBell && root.panelAnchor !== null && !root.expanded

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
                        color: root.critUnread > 0 ? root.colorCrit : (root.unread > 0 ? root.colorOn : root.colorOff)
                        text: root.unread > 0 ? root.unread + " unread"
                            : (hist.count > 0 ? "None unread · " + hist.count + " in history" : "No notifications")
                    }
                    // 3 newest regardless of read state, so hover and popup never disagree
                    Repeater {
                        model: hist
                        Text {
                            visible: index < 3
                            textFormat: Text.PlainText
                            font.pointSize: 10
                            color: root.seen(model.read, model.updated, model.created) ? root.colorRead : root.colorOn
                            text: U.clip(model.applicationName, 14) + " · " + U.clip(model.summary, 40)
                        }
                    }
                }
            }
        }
    }

    // ── Panel view ────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot
        Layout.preferredWidth: panelRow.implicitWidth + 8
        Layout.minimumWidth: panelRow.implicitWidth + 8
        onHeightChanged: if (height > 0) root.panelHeight = height
        Component.onCompleted: root.panelAnchor = compactRoot

        // Real items, each centred on the panel: an inline <img> rides the
        // text baseline and sat ~3px high.
        Row {
            id: panelRow
            anchors.centerIn: parent
            spacing: 3
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: root.panelIconPx
                height: root.panelIconPx
                sourceSize: Qt.size(52, 52)
                smooth: true
                mipmap: true
                source: Qt.resolvedUrl("../icons/" + root.bellFile)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.unread > 0
                textFormat: Text.RichText   // inline colour survives the panel theme
                font.pointSize: root.panelPt
                text: '<span style="color:' + (root.critUnread > 0 ? root.colorCrit : root.colorOn) + ';">' + root.unread + '</span>'
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // top 60% of panel only: overshooting a Chrome tab into the panel must not pop the tip
            onPositionChanged: function(m) {
                var f = mapToItem(null, 0, m.y).y / Window.height
                if (Plasmoid.location === PlasmaCore.Types.BottomEdge ? f > 0.4 : f < 0.6) root.hoverBell = true
            }
            onExited: root.hoverBell = false
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) root.expanded = !root.expanded
                else root.launchApp("plasma-open-settings kcm_notifications")
            }
        }
    }

    // ── Popup view ────────────────────────────────────────────
    fullRepresentation: Item {
        readonly property bool overflow: popupCol.implicitHeight + footer.height + 40 > 600
        implicitWidth: popupCol.width + 36 + (overflow ? 20 : 0)   // 18px margins + a lane for the overlaid ScrollBar only when it shows
        implicitHeight: Math.min(popupCol.implicitHeight + footer.height + 40, 600)
        // Plasma saves the popup size on every close (AppletPopup::hideEvent) and,
        // once saved, ignores implicit size for good. Min/max hints still force a
        // resize, so pin them to the content size. Side effect: no drag-resize.
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            color: "transparent"
            border.color: "#30FFFFFF"
            border.width: 1
            radius: 8
        }

        Flickable {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: 18
            anchors.bottomMargin: 6
            contentWidth: popupCol.width
            contentHeight: popupCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: popupCol
                // Width follows the widest row's unwrapped text, clamped; rows then wrap to it.
                width: Math.min(520, Math.max(340, implicitWidth))
                spacing: 6

                Text {
                    visible: hist.count === 0
                    color: root.colorOff
                    font.pointSize: 9
                    text: "No notifications"
                }

                // Stacked sections instead of tabs: nothing to click, just scroll.
                // Critical urgency pinned on top, then system alerts, personal
                // below. An empty section hides entirely, header included.
                Repeater {
                    model: [{ title: "Critical", sec: 2 }, { title: "System", sec: 1 }, { title: "Personal", sec: 0 }]
                    ColumnLayout {
                        id: section
                        readonly property int sec: modelData.sec
                        Layout.fillWidth: true
                        visible: root.secCount[sec] > 0
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: index > 0 ? 6 : 0
                            spacing: 8
                            Text {
                                font.bold: true
                                font.pointSize: 9.5
                                color: section.sec === 2 ? root.colorCrit : root.colorDim
                                text: modelData.title + (root.secUnread[section.sec] > 0 ? " · " + root.secUnread[section.sec] + " unread" : "")
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#22FFFFFF" }
                            // Only with 2+ sections showing; with one, footer "clear all" is the same thing.
                            TextButton {
                                visible: root.secCount.filter(function(n) { return n > 0 }).length > 1
                                Layout.rightMargin: 14   // ink ends on the × glyphs' ink: rows' 8px padding + × drawn ~6px inside its box (measured)
                                text: "clear"
                                Accessible.name: "Clear " + modelData.title + " notifications"
                                onClicked: root.clearSection(section.sec)
                            }
                        }

                        Repeater {
                            model: hist
                            // Delegate shape: layout + sibling MouseArea inside an Item.
                            // A MouseArea placed directly in a layout becomes a cell.
                            Item {
                                id: row
                                Layout.fillWidth: true
                                readonly property int sec: root.rowSection(model.applicationName, model.desktopEntry, model.notifyRcName, model.urgency)
                                readonly property string group: root.groupOf(model.applicationName, model.summary)
                                readonly property string key: root.keyOf(sec, model.applicationName, model.summary)
                                readonly property bool folded: { root.rev; return root.firstWithKey(key) < index }   // older twin of a head row, drawn inside the head
                                readonly property bool open: !!root.openGroups[key]
                                readonly property int groupN: { root.rev; return root.countKey(key) }
                                visible: !folded && sec === section.sec
                                implicitWidth: rowCol.implicitWidth + 20
                                implicitHeight: rowCol.implicitHeight + 10
                                readonly property bool isCrit: model.urgency === NotificationManager.Notifications.CriticalUrgency
                                readonly property bool seen: root.seen(model.read, model.updated, model.created)
                                readonly property string tag: U.appColor(group || model.applicationName || "")
                                readonly property string plainSummary: U.stripHtml(model.summary)
                                readonly property string plainBody: U.stripHtml(model.body)
                                readonly property var chips: root.chipsEnabled ? U.extractChips(plainSummary + "\n" + plainBody) : []

                                Rectangle {
                                    x: 0; y: 4
                                    width: 3
                                    height: parent.height - 8
                                    radius: 1
                                    color: row.isCrit ? root.colorCrit : row.tag
                                    opacity: row.seen ? 0.45 : 1
                                }

                                ColumnLayout {
                                    id: rowCol
                                    x: 12; y: 5
                                    width: parent.width - 20   // 8px right padding before the scrollbar lane
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            textFormat: Text.PlainText
                                            font.pointSize: 9
                                            font.bold: true
                                            color: row.tag
                                            text: row.group || model.applicationName || "app"
                                        }
                                        Text {
                                            font.pointSize: 9
                                            color: root.colorDim
                                            text: U.relTime(root.now, model.created)
                                        }
                                        Rectangle {
                                            visible: row.groupN > 1
                                            implicitWidth: groupText.implicitWidth + 10
                                            implicitHeight: groupText.implicitHeight + 2
                                            radius: height / 2
                                            color: row.open ? "#334FC3F7" : "#26FFFFFF"
                                            Text {
                                                id: groupText
                                                anchors.centerIn: parent
                                                font.pointSize: 8
                                                font.bold: true
                                                color: root.colorOn
                                                text: "+" + (row.groupN - 1)
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            visible: root.flashRow === row
                                            font.pointSize: 9
                                            color: root.colorAccent
                                            text: "copied"
                                        }
                                        CloseButton { onClicked: root.closeKey(row.key) }   // whole group
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        textFormat: Text.PlainText
                                        font.bold: true
                                        font.pointSize: 10.5
                                        color: row.seen ? root.colorRead : root.colorOn
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        text: row.plainSummary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: row.plainBody !== ""
                                        textFormat: Text.PlainText
                                        font.pointSize: 9.5
                                        color: root.colorDim
                                        wrapMode: Text.Wrap
                                        maximumLineCount: rowMa.containsMouse || row.open ? 40 : 4
                                        elide: Text.ElideRight
                                        text: row.plainBody
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0   // chips wrap to the row; their one-line width must not widen the popup
                                        spacing: 4
                                        visible: root.chipsEnabled && chipRep.count > 0
                                        Repeater {
                                            id: chipRep
                                            model: row.chips
                                            Rectangle {
                                                implicitWidth: chipText.implicitWidth + 12
                                                implicitHeight: chipText.implicitHeight + 6
                                                color: "transparent"
                                                border.color: "#30FFFFFF"
                                                border.width: 1
                                                radius: 4
                                                Text {
                                                    id: chipText
                                                    anchors.centerIn: parent
                                                    textFormat: Text.PlainText
                                                    font.pointSize: 9
                                                    font.family: "monospace"
                                                    color: root.colorAccent
                                                    text: modelData.label
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: function(mouse) {
                                                        if (mouse.modifiers & Qt.ControlModifier) root.openChip(modelData)
                                                        else root.copyText(modelData.value, row)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Unfolded twins, directly under the head: time + body, click copies, × closes that one.
                                    Repeater {
                                        model: { root.rev; return row.open ? root.membersOf(row.key, index) : [] }
                                        Item {
                                            id: twin
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 10
                                            implicitHeight: twinCol.implicitHeight + 4
                                            ColumnLayout {
                                                id: twinCol
                                                width: parent.width
                                                spacing: 1
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Text {
                                                        font.pointSize: 9
                                                        color: root.colorDim
                                                        text: U.relTime(root.now, modelData.created)
                                                    }
                                                    Item { Layout.fillWidth: true }
                                                    Text {
                                                        visible: root.flashRow === twin
                                                        font.pointSize: 9
                                                        color: root.colorAccent
                                                        text: "copied"
                                                    }
                                                    CloseButton { onClicked: hist.close(hist.index(modelData.idx, 0)) }
                                                }
                                                Text {   // rule-based groups mix summaries; show one that differs from the head's
                                                    Layout.fillWidth: true
                                                    visible: modelData.summary !== "" && modelData.summary !== row.plainSummary
                                                    textFormat: Text.PlainText
                                                    font.bold: true
                                                    font.pointSize: 9.5
                                                    color: modelData.seen ? root.colorRead : root.colorOn
                                                    elide: Text.ElideRight
                                                    text: modelData.summary
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: text !== ""
                                                    textFormat: Text.PlainText
                                                    font.pointSize: 9.5
                                                    color: modelData.seen ? root.colorRead : root.colorDim
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 4
                                                    elide: Text.ElideRight
                                                    text: modelData.body
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                z: -1
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.copyText(modelData.body, twin)
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    z: -1   // chips and × sit above and win their clicks
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.modifiers & Qt.ControlModifier) root.openRow(index, row.chips)
                                        else root.copyText(row.plainBody || row.plainSummary, row)
                                    }
                                    // The first click of a double-click still copies; harmless.
                                    onDoubleClicked: root.toggleGroup(row.key)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Fixed footer: never scrolls, so "clear all" is always one click away.
        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottomMargin: 12
            height: footerRow.implicitHeight + 12

            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#22FFFFFF" }

            RowLayout {
                id: footerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 8
                Text {
                    font.pointSize: 9
                    color: root.colorOff
                    text: hist.count === 0 ? "" : hist.count + (hist.count === 1 ? " notification" : " notifications")
                        + (root.unread > 0 ? " · " + root.unread + " unread" : "")
                }
                Item { Layout.fillWidth: true }
                TextButton { visible: hist.count > 0; text: "clear all"; onClicked: root.clearAll() }
            }
        }
    }
}
