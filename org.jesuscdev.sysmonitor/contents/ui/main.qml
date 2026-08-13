import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as PlasmaSupport
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.ksysguard.sensors 1.0 as Sensors

PlasmoidItem {
    id: root
    preferredRepresentation: Plasmoid.compactRepresentation

    // Hover tooltip: content depends on which segment the pointer is over
    property string hoverSeg: ""

    function procLines() {
        var out = []
        if (topProcs.length) {
            var a = []
            for (var i = 0; i < topProcs.length; i++) a.push(topProcs[i].name + " " + topProcs[i].cpu + "%")
            out.push("Top:   " + a.join("  ·  "))
        }
        if (topApps.length) {
            var b = []
            for (var j = 0; j < topApps.length; j++) b.push(topApps[j].name + " " + topApps[j].cpu + "%")
            out.push("Apps:  " + b.join("  ·  "))
        }
        return out.length ? out : ["Gathering…"]
    }

    // Suppress the built-in whole-applet tooltip; we anchor our own per segment
    toolTipMainText: ""
    toolTipSubText: ""

    PlasmaCore.Dialog {
        id: hoverTip
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.ToolTip
        location: Plasmoid.location
        visualParent: root.hoverAnchor
        visible: root.hoverSeg !== "" && root.hoverAnchor !== null && !root.expanded

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
                    spacing: 8

                    Text {
                        font.bold: true
                        font.pointSize: 11
                        color: {
                            switch (root.hoverSeg) {
                            case "bat": return root.batHex
                            case "cpu": return root.cpuHex
                            case "gpu": return root.gpuHex
                            case "ram": return root.ramHex
                            case "net": return root.netHex
                            case "disk": return root.diskHex
                            case "uptime": return root.uptimeHex
                            default: return root.claudeIconHex
                            }
                        }
                        text: {
                            switch (root.hoverSeg) {
                            case "bat": return "Battery " + Math.round(root.batValue) + "%"
                            case "cpu": return "CPU " + root.fmt(root.cpuValue) + "%"
                            case "gpu": return "GPU " + root.fmt(root.gpuValue) + "%"
                            case "ram": return "RAM " + root.ramUsedGB.toFixed(1) + "G / " + root.ramTotalGB.toFixed(1) + "G  (" + Math.round(root.ramValue) + "%)"
                            case "net": return root.netConnected
                                ? "Net  ↓ " + root.fmtNetSpeed(root.netDownBytes) + "   ↑ " + root.fmtNetSpeed(root.netUpBytes)
                                : "Network — disconnected"
                            case "disk": return "Storage " + Math.round(root.diskValue) + "%"
                            case "uptime": return "System"
                            default: return "AI Usage"
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#22888888" }

                    // Battery
                    Text {
                        visible: root.hoverSeg === "bat"
                        color: "#FFFFFF"
                        font.pointSize: 10
                        text: (root.batPowerNow > 0 ? (root.batPowerNow / 1000000).toFixed(1) + "W draw" : "")
                            + (root.fmtBatTime() ? (root.batPowerNow > 0 ? "   ·   " : "") + "~" + root.fmtBatTime() + (root.batCharging ? " until full" : " until empty") : "")
                    }
                    // Brightness bars
                    RowLayout {
                        visible: root.hoverSeg === "bat" && root.screenBrightPct >= 0
                        spacing: 8
                        Text { text: "Screen"; color: "#FFFFFF"; font.pointSize: 9; Layout.preferredWidth: 48 }
                        Rectangle {
                            Layout.preferredWidth: 96; Layout.preferredHeight: 5; radius: 2.5
                            color: "#33888888"
                            Rectangle {
                                width: Math.max(3, parent.width * root.screenBrightPct / 100)
                                height: parent.height; radius: parent.radius
                                color: root.batHex
                            }
                        }
                        Text {
                            text: root.screenBrightPct + "%"
                            color: root.batHex; font.bold: true; font.pointSize: 9
                            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight
                        }
                    }
                    RowLayout {
                        visible: root.hoverSeg === "bat" && root.kbdBrightMax > 0
                        spacing: 8
                        Text { text: "Kbd"; color: "#FFFFFF"; font.pointSize: 9; Layout.preferredWidth: 48 }
                        Rectangle {
                            Layout.preferredWidth: 96; Layout.preferredHeight: 5; radius: 2.5
                            color: "#33888888"
                            Rectangle {
                                width: Math.max(root.kbdBrightLevel > 0 ? 3 : 0,
                                                parent.width * root.kbdBrightLevel / Math.max(1, root.kbdBrightMax))
                                height: parent.height; radius: parent.radius
                                color: root.batHex
                            }
                        }
                        Text {
                            text: root.kbdBrightLevel + "/" + root.kbdBrightMax
                            color: root.batHex; font.bold: true; font.pointSize: 9
                            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight
                        }
                    }
                    // Charge thresholds
                    Text {
                        visible: root.hoverSeg === "bat" && root.batChargeLimit < 100
                        color: root.claudeDimHex
                        font.pointSize: 9
                        text: "Charge limit " + root.batChargeLimit + "%"
                            + (root.batStartThreshold > 0 && root.batStartThreshold < 100
                               ? "   ·   resumes below " + root.batStartThreshold + "%" : "")
                    }

                    // CPU: top by processor
                    ProcTable {
                        visible: root.hoverSeg === "cpu" && root.topProcs.length > 0
                        title: "Top activity"
                        procs: root.topProcs
                    }
                    Item { visible: root.hoverSeg === "cpu" && root.topApps.length > 0; height: 2 }
                    ProcTable {
                        visible: root.hoverSeg === "cpu" && root.topApps.length > 0
                        title: "Top apps"
                        procs: root.topApps
                    }

                    // RAM: top by memory
                    ProcTable {
                        visible: root.hoverSeg === "ram" && root.topMem.length > 0
                        title: "Top memory"
                        procs: root.topMem
                        col1Label: "MEM"
                        col2Label: "SIZE"
                        col1Color: root.ramHex
                        col2Color: root.claudeDimHex
                    }
                    Item { visible: root.hoverSeg === "ram" && root.topMemApps.length > 0; height: 2 }
                    ProcTable {
                        visible: root.hoverSeg === "ram" && root.topMemApps.length > 0
                        title: "Top apps"
                        procs: root.topMemApps
                        col1Label: "MEM"
                        col2Label: "SIZE"
                        col1Color: root.ramHex
                        col2Color: root.claudeDimHex
                    }

                    // GPU: per-process via DRM fdinfo
                    ProcTable {
                        visible: root.hoverSeg === "gpu" && root.gpuProcs.length > 0
                        title: "GPU users"
                        procs: root.gpuProcs
                        col1Label: "GPU"
                        col2Label: ""
                        col1Color: root.gpuHex
                    }
                    Text {
                        visible: root.hoverSeg === "gpu" && root.gpuProcs.length === 0
                        color: root.claudeDimHex
                        font.pointSize: 9
                        text: "GPU idle — no per-app activity right now"
                    }

                    // NET: interface + per-app connections
                    Text {
                        visible: root.hoverSeg === "net" && root.netIface !== ""
                        color: root.claudeDimHex
                        font.pointSize: 9
                        text: root.netIface + "  ·  " + root.netIP
                    }
                    ProcTable {
                        visible: root.hoverSeg === "net" && root.netApps.length > 0
                        title: "Connections"
                        procs: root.netApps
                        col1Label: ""
                        col2Label: ""
                        col1Color: root.netHex
                    }
                    Text {
                        visible: root.hoverSeg === "net" && root.netApps.length === 0
                        color: root.claudeDimHex
                        font.pointSize: 8
                        text: "per-app bandwidth needs root — showing connection counts"
                    }

                    // Storage
                    RowLayout {
                        visible: root.hoverSeg === "disk" && root.diskTotalG > 0
                        spacing: 10
                        Item {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 8
                            Rectangle { anchors.fill: parent; radius: 2; color: "#22FFFFFF" }
                            Rectangle {
                                width: parent.width * Math.min(root.diskValue, 100) / 100
                                height: parent.height
                                radius: 2
                                color: root.diskValue >= 90 ? root.claudeCritHex : root.diskHex
                            }
                        }
                        Text { color: "#FFFFFF"; font.pointSize: 10; text: root.diskUsedG + "G / " + root.diskTotalG + "G" }
                    }

                    // Uptime
                    Text {
                        visible: root.hoverSeg === "uptime"
                        color: "#FFFFFF"
                        font.pointSize: 10
                        text: "Up " + root.fmtUptime(root.uptimeSecs)
                    }
                    Text {
                        visible: root.hoverSeg === "uptime"
                        color: root.claudeDimHex
                        font.pointSize: 10
                        text: "Booted " + Qt.formatDateTime(new Date(Date.now() - root.uptimeSecs * 1000), "ddd MMM d, h:mm AP")
                    }

                    // AI summary
                    GridLayout {
                        visible: root.hoverSeg === "ai"
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 5
                        Text { visible: root.showClaude; color: root.claudeIconHex; font.pointSize: 10; font.bold: true; text: "Claude" }
                        Text {
                            visible: root.showClaude
                            color: "#FFFFFF"; font.pointSize: 10
                            text: {
                                var se = root.claudeLimitByKind("session"), w = root.claudeLimitByKind("weekly_all")
                                return (se ? "5h " + Math.round(se.percent) + "%" : "") + (se && w ? "   ·   " : "") + (w ? "7d " + Math.round(w.percent) + "%" : "")
                            }
                        }
                        Text {
                            visible: root.showClaude && root.fableAlertState(root.fableLimit()) !== ""
                            color: root.fableAccessActive() ? root.claudeCritHex
                                : (root.claudeStale ? root.claudeDimHex
                                    : (root.fableAlertState(root.fableLimit()) === "exhausted"
                                        ? root.claudeCritHex : root.claudeWarnHex))
                            font.pointSize: 10
                            font.bold: true
                            text: "Fable 5"
                        }
                        Text {
                            visible: root.showClaude && root.fableAlertState(root.fableLimit()) !== ""
                            color: root.fableAccessActive() ? root.claudeCritHex
                                : (root.claudeStale ? root.claudeDimHex
                                    : (root.fableAlertState(root.fableLimit()) === "exhausted"
                                        ? root.claudeCritHex : root.claudeWarnHex))
                            font.pointSize: 10
                            font.bold: true
                            text: root.fableHoverText(root.fableLimit())
                        }
                        Text { visible: root.showCodex && root.codexWeekly !== null; color: root.codexIconHex; font.pointSize: 10; font.bold: true; text: "Codex" }
                        Text {
                            visible: root.showCodex && root.codexWeekly !== null
                            color: "#FFFFFF"; font.pointSize: 10
                            text: root.codexWeekly ? "7d " + Math.round(root.codexWeekly.used_percent || 0) + "%" : ""
                        }
                        Text { visible: root.ccusageEnabled && root.ccToday() !== null; color: "#B0BEC5"; font.pointSize: 10; font.bold: true; text: "Today" }
                        Text {
                            visible: root.ccusageEnabled && root.ccToday() !== null
                            color: "#FFFFFF"; font.pointSize: 10
                            text: {
                                var t = root.ccToday()
                                return t ? "$" + (t.totalCost || 0).toFixed(2) + "   ·   " + root.fmtTokens(t.totalTokens || 0) + " tokens" : ""
                            }
                        }
                    }
                }
            }
        }
    }

    property Item hoverAnchor: null

    PlasmaSupport.DataSource {
        id: gpuTopSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                var out = []
                var lines = output.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var f = lines[i].split("\t")
                    if (f.length === 2 && f[0]) out.push({name: f[0], v1: f[1], v2: ""})
                }
                gpuProcs = out
            }
        }
    }

    PlasmaSupport.DataSource {
        id: netInfoSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "")
                delete buffers[source]
                disconnectSource(source)
                var lines = output.split("\n"), apps = [], pastSep = false
                for (var i = 0; i < lines.length; i++) {
                    var ln = lines[i].trim()
                    if (ln === "---") { pastSep = true; continue }
                    if (!ln) continue
                    if (!pastSep) {
                        var f = ln.split(" ")
                        netIface = f[0] || ""
                        netIP = f[1] || ""
                    } else {
                        var m = ln.match(/^(\d+)\s+"(.+)"$/)
                        if (m && apps.length < 3) apps.push({name: m[2], v1: m[1] + " conn", v2: ""})
                    }
                }
                netApps = apps
            }
        }
    }

    function segHovered(seg, item) {
        hoverSeg = seg
        if (item !== undefined) hoverAnchor = item
        if (seg === "cpu" || seg === "ram")
            refreshProcs()
        else if (seg === "gpu")
            gpuTopSource.connectSource("bash " + claudeScriptPath.replace("fetch-usage.sh", "gpu-top.sh"))
        else if (seg === "net")
            netInfoSource.connectSource("sh -c 'ip -o route get 1.1.1.1 2>/dev/null | sed -E \"s/.* dev ([^ ]+).* src ([^ ]+).*/\\1 \\2/\"; echo ---; ss -tnp state established 2>/dev/null | grep -oE \"\\\"[^\\\"]+\\\"\" | sort | uniq -c | sort -rn | head -3 | sed -E \"s/^ +//\"'")
        else if (seg === "disk")
            diskSource.connectSource("sh -c \"df -BG / --output=pcent,size,used | tail -1 | tr -d '%G'\"")
        else if (seg === "uptime")
            uptimeSource.connectSource("sh -c \"awk '{print \\$1}' /proc/uptime\"")
        else if (seg === "bat")
            // ponytail: ThinkPad sysfs paths hardcoded, single-laptop widget
            batInfoSource.connectSource("sh -c \"cat /sys/class/backlight/intel_backlight/brightness /sys/class/backlight/intel_backlight/max_brightness '/sys/class/leds/tpacpi::kbd_backlight/brightness' '/sys/class/leds/tpacpi::kbd_backlight/max_brightness' /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null\"")
    }

    // Font Awesome
    FontLoader { id: faFont; source: "../fonts/fa-solid-900.ttf" }

    // Current values (raw decimals)
    property real cpuValue: 0.0
    property real gpuValue: 0.0
    property real ramValue: 0.0
    property real ramUsedGB: 0.0
    property real batValue: -1.0    // -1 = no battery detected
    property bool batCharging: false
    property real cpuTemp: 0.0
    property real gpuTemp: 0.0
    property real netDownBytes: 0.0  // bytes/sec download rate
    property real diskValue: 0.0
    property int diskTotalG: 0
    property int diskUsedG: 0
    property real uptimeSecs: 0.0
    property real batEnergyNow: 0.0
    property real batEnergyFull: 0.0
    property real batPowerNow: 0.0
    property int batChargeLimit: 100  // 0-100, from charge_control_end_threshold
    property int batStartThreshold: 0   // charging resumes below this, from charge_control_start_threshold
    property int screenBrightPct: -1    // -1 = not read yet
    property int kbdBrightLevel: 0
    property int kbdBrightMax: 0

    // CPU delta tracking
    property real prevCpuIdle: 0
    property real prevCpuTotal: 0
    property bool cpuFirstRun: true

    // Network delta tracking
    property real prevNetRxBytes: 0
    property bool netFirstRun: true
    property bool netConnected: true

    // Trend arrow tracking
    property real prevCpuDisplay: 0.0
    property real prevGpuDisplay: 0.0
    property real prevRamDisplay: 0.0

    // Settings (persisted via Plasmoid.configuration)
    property bool useDecimals: Plasmoid.configuration.useDecimals
    property bool ramShowGB: Plasmoid.configuration.ramShowGB
    property bool brightColors: Plasmoid.configuration.brightColors
    property bool warnEnabled: Plasmoid.configuration.warnEnabled
    property bool showCpu: Plasmoid.configuration.showCpu
    property bool showGpu: Plasmoid.configuration.showGpu
    property bool showRam: Plasmoid.configuration.showRam
    property bool showBat: Plasmoid.configuration.showBat
    property bool showNet: Plasmoid.configuration.showNet
    property bool showCpuTemp: Plasmoid.configuration.showCpuTemp
    property bool showGpuTemp: Plasmoid.configuration.showGpuTemp
    property bool showDisk: Plasmoid.configuration.showDisk
    property bool showTrendArrows: Plasmoid.configuration.showTrendArrows
    property bool showBatTime: Plasmoid.configuration.showBatTime
    property bool showUptime: Plasmoid.configuration.showUptime
    property int updateIntervalSec: Plasmoid.configuration.updateIntervalSec
    property bool batOnRight: Plasmoid.configuration.batOnRight
    property bool showChargingIcon: Plasmoid.configuration.showChargingIcon
    property int itemSpacing: Plasmoid.configuration.itemSpacing
    property bool showBatSpacer: Plasmoid.configuration.showBatSpacer
    property string clickCommand: Plasmoid.configuration.clickCommand
    property bool useIcons: Plasmoid.configuration.useIcons
    property bool batteryModeEnabled: Plasmoid.configuration.batteryModeEnabled
    property int batteryModeInterval: Plasmoid.configuration.batteryModeInterval

    // Claude usage settings
    property bool showClaude: Plasmoid.configuration.showClaude
    property int claudeIntervalSec: Plasmoid.configuration.claudeIntervalSec
    property int claudeWarnThreshold: Plasmoid.configuration.claudeWarnThreshold
    property int claudeCritThreshold: Plasmoid.configuration.claudeCritThreshold
    property bool ccusageEnabled: Plasmoid.configuration.ccusageEnabled
    property string ccusagePath: Plasmoid.configuration.ccusagePath

    // Claude usage state
    property var claudeLimits: []
    property string claudePlan: ""
    property string claudeTier: ""
    property bool claudeStale: false
    property string claudeError: ""
    property double claudeFetchedAt: 0   // epoch seconds
    property var claudePaidUsageEnabled: null  // true/false when reported, null when unknown
    // Local Claude Code denial evidence. The usage endpoint can still report a
    // partial Fable percentage after the model has begun requiring credits.
    property var claudeFableAccess: ({})
    property var ccDaily: []
    property double ccFetchedAt: 0       // epoch ms
    property bool ccRunning: false

    // Codex/ChatGPT usage state: weekly from free wham/usage endpoint (account-wide,
    // covers other machines); optional 5h window from local session logs
    property bool showCodex: Plasmoid.configuration.showCodex
    property bool aiResetCountdown: Plasmoid.configuration.aiResetCountdown

    // ── Panel font scaling: track panel thickness, ~10pt at the default 40px ──
    property real panelHeight: 0
    readonly property real panelPt: panelHeight > 0
        ? Math.max(10, Math.round(panelHeight * 0.33 * 2) / 2) : 10
    readonly property int panelIconPx: Math.round(panelPt * 1.3)
    property int aiTick: 0  // bumped each minute so countdown labels re-render between fetches
    Timer {
        interval: 60000; repeat: true
        running: (root.aiResetCountdown || root.fableAccessActive()
            || root.fableAlertState(root.fableLimit()) !== "")
            && (root.showClaude || root.showCodex)
        onTriggered: root.aiTick++
    }
    // countdown text when enabled, else static window label ("5h"/"7d")
    function aiWinLabel(fallback, countdown) {
        return (aiResetCountdown && countdown) ? countdown : fallback
    }
    property var codexWeekly: null       // {used_percent, resets_at, fetched_at}
    property var codexSession: null      // {used_percent, resets_at, fetched_at} or null
    property string codexPlan: ""
    property var codexFeatures: []
    readonly property double codexFetchedAt: codexWeekly ? codexWeekly.fetched_at : 0
    readonly property bool codexOld: codexFetchedAt > 0 && (Date.now() / 1000 - codexFetchedAt) > 1800

    // Notifications + sparkline + on-demand process list
    property bool notifyEnabled: Plasmoid.configuration.notifyEnabled
    property bool showCostPanel: Plasmoid.configuration.showCostPanel
    property var usageNotificationState: ({version: 1, meters: ({})})
    property bool usageNotificationStateLoaded: false
    property bool usageNotificationStateDirty: false
    property var claudeHist: []   // [{t, p}] session % samples, last 24h shown
    property var codexHist: []    // [{t, p}] weekly % samples
    property var topProcs: []     // top 3 by CPU, any process — fetched only on sys-popup open
    property var topApps: []      // top 3 excluding system/background processes
    property var topMem: []       // memory view of the same aggregation
    property var topMemApps: []
    property var gpuProcs: []     // [{name, v1: pct}] from gpu-top.sh
    property var netApps: []      // [{name, v1: "N conns"}]
    property string netIface: ""
    property string netIP: ""
    property real ramTotalGB: 0
    property real netUpBytes: 0
    property real prevNetTxBytes: 0

    function shellQuote(value) {
        return "'" + String(value).split("'").join("'\"'\"'") + "'"
    }

    function notify(title, body, persistent) {
        var flags = persistent
            ? " --urgency=critical --expire-time=0"
            : " --urgency=normal"
        launchSource.connectSource("notify-send --app-name 'AI Usage'"
            + " --icon office-chart-line" + flags + " -- "
            + shellQuote(title) + " " + shellQuote(body))
    }

    function loadUsageNotificationState() {
        var state = null
        try {
            state = JSON.parse(String(Plasmoid.configuration.usageNotificationState || "{}"))
        } catch (e) { state = null }
        if (!state || state.version !== 1 || !state.meters)
            state = {version: 1, meters: ({})}
        usageNotificationState = state
        usageNotificationStateLoaded = true
        usageNotificationStateDirty = false
    }

    function flushUsageNotificationState() {
        if (!usageNotificationStateLoaded || !usageNotificationStateDirty) return
        Plasmoid.configuration.usageNotificationState = JSON.stringify(usageNotificationState)
        Plasmoid.configuration.writeConfig()
        usageNotificationStateDirty = false
    }

    function usageResetKey(resetAt) {
        if (resetAt === null || resetAt === undefined || resetAt === "") return "unknown"
        var n = Number(resetAt)
        if (!isNaN(n)) {
            if (n <= 0) return "unknown"
            return String(Math.round((n < 100000000000 ? n * 1000 : n) / 60000))
        }
        var ms = new Date(String(resetAt)).getTime()
        return isNaN(ms) ? "unknown" : String(Math.round(ms / 60000))
    }

    function usageWindowRolled(previousKey, currentKey) {
        var previousMinute = Number(previousKey)
        var currentMinute = Number(currentKey)
        if (isNaN(previousMinute) || isNaN(currentMinute)) return false
        // Reset timestamps can drift slightly between API samples. Only clear
        // a full latch after the old boundary actually passed and the server
        // advanced the window by more than that jitter.
        return currentMinute > previousMinute + 5
            && Date.now() / 60000 >= previousMinute - 1
    }

    function usageResetExpired(resetAt) {
        var key = usageResetKey(resetAt)
        return key !== "unknown" && Number(key) < Date.now() / 60000 - 5
    }

    function usageSampleFresh(fetchedAt) {
        var fetched = Number(fetchedAt)
        return !isNaN(fetched) && fetched > 0
            && Date.now() / 1000 - fetched <= 1800
    }

    function usageMeterSlug(value) {
        return String(value || "unknown").toLowerCase().replace(/[^a-z0-9]+/g, "_")
    }

    function claudeMeterId(l) {
        if (isFableLimit(l)) return "claude:weekly_scoped:fable"
        var id = "claude:" + String(l.kind || "unknown")
        if (l.kind === "weekly_scoped") {
            var model = l.scope && l.scope.model && l.scope.model.display_name
            var surface = l.scope && l.scope.surface
            id += ":" + usageMeterSlug(model) + ":" + usageMeterSlug(surface)
        }
        return id
    }

    function usageResetDetail(resetAt) {
        var reset = usageResetCountdown(resetAt)
        return reset && reset !== "now"
            ? "Usage is available again · next reset in " + reset + "."
            : "Usage is available again."
    }

    function usageResetCountdown(resetAt) {
        var key = usageResetKey(resetAt)
        return key === "unknown" ? ""
            : claudeFmtReset(new Date(Number(key) * 60000).toISOString())
    }

    function usageUnavailableDetail(provider, resetAt) {
        var reset = usageResetCountdown(resetAt)
        return provider + " reported that this limit has no usage available."
            + (reset && reset !== "now" ? " Resets in " + reset + "." : "")
    }

    // Observe bands, not every percentage point. "full" stays latched until
    // zero (or a new reset window), preventing 100↔99 rounding from re-alerting.
    // A meter's first sample is always a silent baseline after upgrades/reloads.
    function observeUsageMeter(id, label, percent, resetAt, forcedFull, fullDetail) {
        if (!usageNotificationStateLoaded) return
        if (usageResetExpired(resetAt)) return
        var missingPercent = percent === null || percent === undefined || percent === ""
        if (missingPercent && forcedFull !== true) return
        var pct = missingPercent ? 100 : Number(percent)
        if (isNaN(pct)) return
        var windowKey = usageResetKey(resetAt)
        var resetCountdown = usageResetCountdown(resetAt)
        var rawBand = (forcedFull === true || pct >= 100) ? "full"
            : (pct <= 0 ? "zero" : "active")
        var meters = usageNotificationState.meters
        var previous = meters[id]

        if (!previous) {
            meters[id] = {band: rawBand, window: windowKey}
            usageNotificationStateDirty = true
            return
        }

        var sameWindow = previous.window === windowKey
        var rolledWindow = !sameWindow && usageWindowRolled(previous.window, windowKey)
        var nextBand = rawBand
        var nextWindow = windowKey
        if (previous.band === "full" && rawBand !== "zero" && !rolledWindow) {
            nextBand = "full"
            nextWindow = previous.window
        }

        var sendFull = notifyEnabled && rawBand === "full"
            && (previous.band !== "full" || rolledWindow)
        var sendReset = notifyEnabled && rawBand === "zero" && previous.band !== "zero"

        if (previous.band !== nextBand || previous.window !== nextWindow) {
            meters[id] = {band: nextBand, window: nextWindow}
            usageNotificationStateDirty = true
        }
        // Commit the event before delivery so a sudden Plasma restart cannot
        // replay a notification the user has already seen or dismissed.
        if (sendFull || sendReset) flushUsageNotificationState()
        if (sendFull)
            notify(label + " has no usage left",
                fullDetail || ("100% used."
                    + (resetCountdown && resetCountdown !== "now"
                        ? " Resets in " + resetCountdown + "." : "")), true)
        else if (sendReset)
            notify(label + " reset to 0%", usageResetDetail(resetAt), false)
    }

    // Which section the popup shows: "sys" (middle-click on metrics) or "claude" (click Claude segment)
    property string popupMode: "sys"

    function togglePopup(mode) {
        if (expanded && popupMode === mode) {
            expanded = false
        } else {
            popupMode = mode
            expanded = true
        }
    }

    // Warning thresholds
    property int cpuWarnThreshold: Plasmoid.configuration.cpuWarnThreshold
    property int gpuWarnThreshold: Plasmoid.configuration.gpuWarnThreshold
    property int ramWarnThreshold: Plasmoid.configuration.ramWarnThreshold
    property int batWarnThreshold: Plasmoid.configuration.batWarnThreshold

    // Custom color overrides (empty string = use default)
    property string cpuColorOverride: Plasmoid.configuration.cpuColor
    property string gpuColorOverride: Plasmoid.configuration.gpuColor
    property string ramColorOverride: Plasmoid.configuration.ramColor
    property string batColorOverride: Plasmoid.configuration.batColor
    property string netColorOverride: Plasmoid.configuration.netColor
    property string diskColorOverride: Plasmoid.configuration.diskColor
    property string uptimeColorOverride: Plasmoid.configuration.uptimeColor
    property string warnColorOverride: Plasmoid.configuration.warnColor

    // Effective interval (accounts for battery mode)
    property int effectiveIntervalMs: {
        if (batteryModeEnabled && batValue >= 0 && !batCharging)
            return batteryModeInterval * 1000
        return updateIntervalSec * 1000
    }

    component LimitRow: RowLayout {
        id: lr
        property string label
        property real pct: 0
        property string barColor: "#FFFFFF"
        property string resetTxt
        property string resetColor: "#90CAF9"
        spacing: 10
        Text { text: lr.label; color: "#FFFFFF"; font.pointSize: 11; Layout.preferredWidth: 200; elide: Text.ElideRight }
        Item {
            Layout.preferredWidth: 110
            Layout.preferredHeight: 8
            Rectangle { anchors.fill: parent; radius: 2; color: "#22FFFFFF" }
            Rectangle {
                width: parent.width * Math.min(lr.pct, 100) / 100
                height: parent.height
                radius: 2
                color: lr.barColor
            }
        }
        Text { text: Math.round(lr.pct) + "%"; color: lr.barColor; font.bold: true; font.pointSize: 11; Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight }
        Text { text: "\u21BB " + lr.resetTxt; color: lr.resetColor; font.pointSize: 10 }
    }

    component ProcTable: GridLayout {
        id: pt
        property string title
        property var procs: []          // [{name, v1, v2}]
        property string col1Label: "CPU"
        property string col2Label: "MEM"
        property string col1Color: root.cpuHex
        property string col2Color: root.ramHex
        columns: col2Label !== "" ? 3 : 2
        rows: procs.length + 1
        flow: GridLayout.TopToBottom
        columnSpacing: 16
        rowSpacing: 3

        Text { text: pt.title; color: "#B0BEC5"; font.bold: true; font.pointSize: 10 }
        Repeater {
            model: pt.procs
            Text { text: modelData.name; color: "#FFFFFF"; font.pointSize: 10 }
        }
        Text { text: pt.col1Label; color: root.claudeDimHex; font.pointSize: 9 }
        Repeater {
            model: pt.procs
            Text { text: modelData.v1; color: pt.col1Color; font.pointSize: 10; Layout.alignment: Qt.AlignRight }
        }
        Text { visible: pt.col2Label !== ""; text: pt.col2Label; color: root.claudeDimHex; font.pointSize: 9 }
        Repeater {
            model: pt.col2Label !== "" ? pt.procs : []
            Text { text: modelData.v2; color: pt.col2Color; font.pointSize: 10; Layout.alignment: Qt.AlignRight }
        }
    }

    // ── Color definitions ───────────────────────────────────────
    readonly property string cpuHexNormal: "#42A5F5"    // blue
    readonly property string gpuHexNormal: "#66BB6A"    // green
    readonly property string ramHexNormal: "#AB47BC"    // purple
    readonly property string batHexNormal: "#FDD835"    // yellow
    readonly property string netHexNormal: "#4DD0E1"    // cyan
    readonly property string diskHexNormal: "#FFA726"   // orange
    readonly property string uptimeHexNormal: "#B0BEC5" // light gray

    readonly property string cpuHexBright: "#80D8FF"
    readonly property string gpuHexBright: "#69F0AE"
    readonly property string ramHexBright: "#EA80FC"
    readonly property string batHexBright: "#FFEE58"
    readonly property string netHexBright: "#80DEEA"
    readonly property string diskHexBright: "#FFB74D"
    readonly property string uptimeHexBright: "#ECEFF1"

    readonly property string warnHexNormal: "#EF5350"
    readonly property string warnHexBright: "#FF5252"
    property string warnHex: warnColorOverride !== ""
        ? warnColorOverride : (brightColors ? warnHexBright : warnHexNormal)

    // Resolved colors (accounting for warnings, then overrides, then bright/normal)
    property string cpuHex: (warnEnabled && cpuValue >= cpuWarnThreshold)
        ? warnHex : (cpuColorOverride !== "" ? cpuColorOverride : (brightColors ? cpuHexBright : cpuHexNormal))
    property string gpuHex: (warnEnabled && gpuValue >= gpuWarnThreshold)
        ? warnHex : (gpuColorOverride !== "" ? gpuColorOverride : (brightColors ? gpuHexBright : gpuHexNormal))
    property string ramHex: (warnEnabled && ramValue >= ramWarnThreshold)
        ? warnHex : (ramColorOverride !== "" ? ramColorOverride : (brightColors ? ramHexBright : ramHexNormal))
    property string batHex: (warnEnabled && batValue >= 0 && batValue <= batWarnThreshold)
        ? warnHex : (batColorOverride !== "" ? batColorOverride : (brightColors ? batHexBright : batHexNormal))
    property string netHex: !netConnected
        ? warnHex : (netColorOverride !== "" ? netColorOverride : (brightColors ? netHexBright : netHexNormal))
    property string diskHex: (warnEnabled && diskValue >= 90)
        ? warnHex : (diskColorOverride !== "" ? diskColorOverride : (brightColors ? diskHexBright : diskHexNormal))
    property string uptimeHex: uptimeColorOverride !== ""
        ? uptimeColorOverride : (brightColors ? uptimeHexBright : uptimeHexNormal)

    // ── Claude usage colors (pastel) + helpers ──────────────────
    readonly property string claudeIconHex: "#C15F3C"    // Claude crail (claude.ai accent)
    readonly property string claudeOkHex: "#FFCC80"      // light orange — usage %
    readonly property string claudeWarnHex: "#FF9E45"    // hot orange
    readonly property string claudeCritHex: "#EF9A9A"    // pastel red
    readonly property string claudeResetHex: "#90CAF9"   // pastel blue — time windows/resets, distinct from usage %
    readonly property string claudeDimHex: "#8A8A8A"

    function claudePctColor(p) {
        if (claudeStale) return claudeDimHex
        if (p >= claudeCritThreshold) return claudeCritHex
        if (p >= claudeWarnThreshold) return claudeWarnHex
        return claudeOkHex
    }

    function claudeLimitByKind(kind) {
        for (var i = 0; i < claudeLimits.length; i++)
            if (claudeLimits[i].kind === kind) return claudeLimits[i]
        return null
    }

    function claudeLimitLabel(l) {
        if (l.kind === "session") return "Session (5h)"
        if (l.kind === "weekly_all") return "Weekly (all)"
        if (l.kind === "weekly_scoped") {
            var modelName = (l.scope && l.scope.model && l.scope.model.display_name) || "model"
            if (String(modelName).toLowerCase().indexOf("fable") >= 0)
                return "Fable 5 included (50% cap)"
            return "Weekly " + modelName
        }
        return l.kind
    }

    function isFableLimit(l) {
        if (!l || l.kind !== "weekly_scoped") return false
        var modelName = l.scope && l.scope.model && l.scope.model.display_name
        return !!modelName && String(modelName).toLowerCase().indexOf("fable") >= 0
    }

    function fableLimitFrom(limits) {
        var fallback = null
        for (var i = 0; i < limits.length; i++) {
            var l = limits[i]
            if (!isFableLimit(l)) continue
            if (l.is_active === true) return l
            if (fallback === null || Number(l.percent || 0) > Number(fallback.percent || 0))
                fallback = l
        }
        return fallback
    }

    function fableLimit() {
        return fableLimitFrom(claudeLimits)
    }

    function fableAccessActive() {
        var tick = aiTick  // expire the local marker promptly at the weekly reset
        var access = claudeFableAccess || {}
        if (access.exhausted !== true || !access.resets_at) return false
        var resetMs = new Date(String(access.resets_at)).getTime()
        return !isNaN(resetMs) && resetMs > Date.now()
    }

    function fableEffectiveReset(l) {
        if (fableAccessActive() && claudeFableAccess.resets_at)
            return String(claudeFableAccess.resets_at)
        return l && l.resets_at ? String(l.resets_at) : ""
    }

    function fableAlertState(l) {
        var tick = aiTick  // stop cached API alerts when their weekly window ends
        // An actual Claude Code model fallback is more authoritative than the
        // advisory usage meter, which can continue to show less than 100%.
        if (fableAccessActive()) return "exhausted"
        if (!l) return ""
        if (l.resets_at) {
            var resetMs = new Date(String(l.resets_at)).getTime()
            if (!isNaN(resetMs) && resetMs <= Date.now()) return ""
        }
        var pct = fablePercent(l)
        var severity = String(l.severity || "").toLowerCase()
        if (l.limit_reached === true || (!isNaN(pct) && pct >= 100)
                || severity === "reached" || severity === "exceeded"
                || severity === "exhausted" || severity === "blocked")
            return "exhausted"
        if (severity === "warning" || severity === "critical" || severity === "danger"
                || (!isNaN(pct) && pct >= claudeCritThreshold))
            return "warning"
        return ""
    }

    function claudeLimitTerminal(l) {
        if (!l) return false
        var severity = String(l.severity || "").toLowerCase()
        return l.limit_reached === true || severity === "reached"
            || severity === "exceeded" || severity === "exhausted"
            || severity === "blocked"
    }

    function claudeLimitColor(l) {
        if (isFableLimit(l) && fableAccessActive()) return claudeCritHex
        if (claudeStale) return claudeDimHex
        if (isFableLimit(l)) {
            var state = fableAlertState(l)
            if (state === "exhausted") return claudeCritHex
            if (state === "warning") return claudeWarnHex
        }
        return claudePctColor(Number(l.percent || 0))
    }

    function fablePercent(l) {
        if (!l || l.percent === null || l.percent === undefined || l.percent === "") return NaN
        return Number(l.percent)
    }

    function fableHoverText(l) {
        var tick = aiTick
        var state = fableAlertState(l)
        if (state === "exhausted") {
            var reset = claudeFmtReset(fableEffectiveReset(l))
            if (reset === "now") return "INCLUDED OUT · reset due now"
            return reset ? "INCLUDED OUT · resets in " + reset
                : "INCLUDED OUT · until weekly reset"
        }
        if (!l) return ""
        var pct = fablePercent(l)
        return isNaN(pct) ? "API METER · LOW"
            : "API meter " + Math.round(pct) + "% · LOW"
    }

    function fableAlertDetail(l, staleOverride) {
        var tick = aiTick  // refresh the reset countdown while the popup is open
        var reset = claudeFmtReset(fableEffectiveReset(l))
        var resetText = reset === "now" ? " Reset due now."
            : (reset ? " Resets in " + reset + "." : "")
        if (fableAccessActive())
            return "Claude Code reported that Fable 5 requires usage credits."
                + " Included Fable access is out until the weekly reset."
                + resetText
                + fablePaidUsageAdvice()
        if (!l) return ""
        var dataStale = staleOverride === undefined ? claudeStale : staleOverride
        var prefix = dataStale ? "Last known — " : ""
        if (fableAlertState(l) === "exhausted")
            return prefix + "The Fable allowance capped at 50% of weekly plan usage is used up."
                + resetText
                + fablePaidUsageAdvice()
        var pct = fablePercent(l)
        return prefix + (isNaN(pct) ? "The Fable API meter is running low."
            : "The Fable API meter reports " + Math.round(pct) + "% used.")
            + " Fable has a separate included allowance capped at 50% of weekly plan usage,"
            + " and actual access may stop before this meter reaches 100%."
            + resetText
    }

    function fablePaidUsageAdvice() {
        if (claudePaidUsageEnabled === true)
            return " Paid usage credits are enabled, so further Fable use may be billed."
        if (claudePaidUsageEnabled === false)
            return " Switch models until then, or enable paid usage credits."
        return " Switch models until then unless paid usage credits are enabled."
    }

    function claudeFmtReset(iso) {
        if (!iso) return ""
        var ms = new Date(iso).getTime() - Date.now()
        if (isNaN(ms) || ms <= 0) return "now"
        var m = Math.floor(ms / 60000)
        var d = Math.floor(m / 1440)
        var h = Math.floor((m % 1440) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + (m % 60) + "m"
        return (m % 60) + "m"
    }

    function claudeIconHtml() {
        return '<img src="' + Qt.resolvedUrl("../icons/claude-mascot.png") + '" width="' + root.panelIconPx + '" height="' + root.panelIconPx + '"> '
    }

    function claudeItemHtml() {
        var tick = aiTick  // dependency: minute timer refreshes countdowns
        var s = claudeLimitByKind("session")
        var w = claudeLimitByKind("weekly_all")
        var parts = []
        if (s) parts.push('<span style="color:' + claudeResetHex + ';">' + aiWinLabel("5h", claudeFmtReset(s.resets_at)) + ' </span>'
            + '<span style="color:' + claudePctColor(s.percent) + ';">' + fmtPct(s.percent) + '</span>')
        if (w) parts.push('<span style="color:' + claudeResetHex + ';">' + aiWinLabel("7d", claudeFmtReset(w.resets_at)) + ' </span>'
            + '<span style="color:' + claudePctColor(w.percent) + ';">' + fmtPct(w.percent) + '</span>')
        var body = parts.length ? parts.join('<span style="color:' + claudeDimHex + ';">&#183; </span>')
                                : '<span style="color:' + claudeDimHex + ';">…</span>'
        return '<b>' + claudeIconHtml() + body + '</b>'
    }

    // ── Codex (ChatGPT) helpers ─────────────────────────────────
    // Own teal family so Codex reads apart from Claude's orange at a glance.
    // Same split as Claude: usage % in one hue, time windows/resets in another.
    readonly property string codexIconHex: "#7FD8BE"     // pastel OpenAI teal
    readonly property string codexOkHex: "#8FE3C8"       // light teal — usage %
    readonly property string codexLabelHex: "#B39DDB"    // pastel lavender — window labels
    readonly property string codexResetHex: "#B39DDB"    // pastel lavender — reset countdowns

    function codexPctColor(p) {
        if (codexOld) return claudeDimHex
        if (p >= claudeCritThreshold) return claudeCritHex
        if (p >= claudeWarnThreshold) return claudeWarnHex
        return codexOkHex
    }

    function codexRowsList() {
        var out = []
        if (codexSession) out.push({label: "Session (5h)", pct: codexSession.used_percent || 0, resets_at: codexSession.resets_at})
        if (codexWeekly) out.push({label: "Weekly (account)", pct: codexWeekly.used_percent || 0, resets_at: codexWeekly.resets_at})
        for (var i = 0; i < codexFeatures.length; i++)
            out.push({label: codexFeatures[i].name, pct: codexFeatures[i].used_percent || 0, resets_at: codexFeatures[i].resets_at})
        return out
    }

    function codexIconHtml() {
        return '<img src="' + Qt.resolvedUrl("../icons/codex-mascot.png") + '" width="' + root.panelIconPx + '" height="' + root.panelIconPx + '"> '
    }

    property bool checking: false

    function forceCheck() {
        checking = true
        claudeSource.connectSource("bash " + claudeScriptPath)
        if (showCodex)
            codexSource.connectSource("bash " + claudeScriptPath.replace("fetch-usage.sh", "fetch-codex.sh") + " force")
        if (ccusageEnabled) {
            ccFetchedAt = 0
            refreshCcusage()
        }
    }

    function codexItemHtml() {
        if (!codexWeekly && !codexSession)
            return '<b>' + codexIconHtml() + '<span style="color:' + claudeDimHex + ';">…</span></b>'
        var parts = []
        var tick = aiTick  // dependency: minute timer refreshes countdowns
        if (codexSession)
            parts.push('<span style="color:' + codexLabelHex + ';">' + aiWinLabel("5h", fmtEpochReset(codexSession.resets_at)) + ' </span>'
                + '<span style="color:' + codexPctColor(codexSession.used_percent || 0) + ';">' + fmtPct(codexSession.used_percent || 0) + '</span>')
        if (codexWeekly)
            parts.push('<span style="color:' + codexLabelHex + ';">' + aiWinLabel("7d", fmtEpochReset(codexWeekly.resets_at)) + ' </span>'
                + '<span style="color:' + codexPctColor(codexWeekly.used_percent || 0) + ';">' + fmtPct(codexWeekly.used_percent || 0) + '</span>')
        return '<b>' + codexIconHtml() + parts.join('<span style="color:' + claudeDimHex + ';">&#183; </span>') + '</b>'
    }

    function fmtAgo(epochSec) {
        if (!epochSec) return "never"
        var m = Math.floor((Date.now() / 1000 - epochSec) / 60)
        if (m < 1) return "just now"
        if (m < 60) return m + "m ago"
        return Math.floor(m / 60) + "h " + (m % 60) + "m ago"
    }

    function codexAge() {
        if (!codexFetchedAt) return ""
        var m = Math.floor((Date.now() / 1000 - codexFetchedAt) / 60)
        if (m < 2) return "just now"
        if (m < 120) return m + "m ago"
        if (m < 2880) return Math.floor(m / 60) + "h ago"
        return Math.floor(m / 1440) + "d ago"
    }

    function fmtEpochReset(epoch) {
        if (!epoch) return ""
        var ms = epoch * 1000 - Date.now()
        if (ms <= 0) return "now"
        var m = Math.floor(ms / 60000)
        var d = Math.floor(m / 1440)
        var h = Math.floor((m % 1440) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + (m % 60) + "m"
        return (m % 60) + "m"
    }

    function ccToday() {
        return ccDaily.length ? ccDaily[ccDaily.length - 1] : null
    }
    // Cost+tokens over the trailing N days (ccDaily now holds 30 days)
    function ccRange(days) {
        var d = new Date(Date.now() - (days - 1) * 86400000)
        var iso = d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
        var cost = 0, tok = 0
        for (var i = 0; i < ccDaily.length; i++) {
            if ((ccDaily[i].period || ccDaily[i].date || "") >= iso) {
                cost += ccDaily[i].totalCost || 0
                tok += ccDaily[i].totalTokens || 0
            }
        }
        return { cost: cost, tokens: tok }
    }
    function fmtTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
        return "" + Math.round(n)
    }

    // ── Font Awesome icon helpers ─────────────────────────────────
    function faIcon(unicode, color) {
        // &nbsp; not plain space: rich text trims trailing spaces, label would touch value
        return '<span style="font-family:\'' + faFont.name + '\'; color:' + color + ';">&#x' + unicode + ';</span>&nbsp;'
    }

    function metricLabel(text, iconUnicode, color, seg) {
        // seg given = generated PNG icon exists for it; battery + net-disconnected stay font glyphs
        if (seg !== undefined && useIcons) {
            // red-tinted variant when the metric is in warn state (only cpu/gpu/ram/disk have one)
            var warn = color === warnHex && ["cpu", "gpu", "ram", "disk"].indexOf(seg) >= 0 ? "-warn" : ""
            return '<img src="' + Qt.resolvedUrl("../icons/metric-" + seg + warn + ".png") + '" width="' + root.panelIconPx + '" height="' + root.panelIconPx + '">&nbsp;'
        }
        if (useIcons && faFont.status === FontLoader.Ready)
            return faIcon(iconUnicode, color)
        return text + '&nbsp;'
    }

    // Format helpers — no padding here; MetricItem reserves pixel width instead
    function fmt(val) {
        return useDecimals ? val.toFixed(1) : Math.round(val).toString()
    }

    function fmtPct(val) {
        return fmt(val) + '%'
    }

    // Widest possible percentage string, for width reservation
    readonly property string maxPct: useDecimals ? "100.0%" : "100%"

    function fmtRam() {
        if (ramShowGB) return ramUsedGB.toFixed(1) + 'GB'
        return fmtPct(ramValue)
    }

    function fmtNetSpeed(bytesPerSec) {
        if (bytesPerSec >= 1073741824) return (bytesPerSec / 1073741824).toFixed(1) + 'G/s'
        if (bytesPerSec >= 1048576) return (bytesPerSec / 1048576).toFixed(1) + 'M/s'
        return (bytesPerSec / 1024).toFixed(0) + 'K/s'
    }

    function fmtUptime(secs) {
        var d = Math.floor(secs / 86400)
        var h = Math.floor((secs % 86400) / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (d > 0) return d + 'd ' + h + 'h'
        if (h > 0) return h + 'h ' + m + 'm'
        return m + 'm'
    }

    function fmtBatTime() {
        if (batPowerNow <= 0) return ''
        var hours = 0
        if (batCharging) {
            var targetEnergy = batEnergyFull * (batChargeLimit / 100.0)
            if (batEnergyNow >= targetEnergy) return ''
            hours = (targetEnergy - batEnergyNow) / batPowerNow
        } else {
            hours = batEnergyNow / batPowerNow
        }
        if (hours < 0 || hours > 99) return ''
        var h = Math.floor(hours)
        var m = Math.round((hours - h) * 60)
        if (h > 0) return h + 'h' + (m > 0 ? ' ' + m + 'm' : '')
        return m + 'm'
    }

    function trendArrow(current, previous) {
        if (!showTrendArrows) return ''
        var delta = current - previous
        if (delta > 2) return ' &#x2191;'   // up arrow
        if (delta < -2) return ' &#x2193;'  // down arrow
        return ''  // MetricItem maxValue reserves the arrow slot
    }

    // Battery icon based on percentage (scales with charge limit)
    function batIconUnicode() {
        // Scale percentage relative to charge limit so e.g. 80% with 80% limit = full
        var pct = batChargeLimit < 100 ? (batValue / batChargeLimit) * 100 : batValue
        if (pct >= 80) return 'f240'       // battery-full
        if (pct >= 55) return 'f241'       // battery-three-quarters
        if (pct >= 30) return 'f242'       // battery-half
        if (pct >= 10) return 'f243'       // battery-quarter
        return 'f244'                       // battery-empty
    }

    // ── Click action helpers ────────────────────────────────────
    function launchApp(cmd) {
        if (cmd !== "")
            launchSource.connectSource("sh -c '" + cmd + " &'")
    }

    property string sysFocus: "cpu"
    property bool sysPopupEnabled: Plasmoid.configuration.sysPopupEnabled

    // Click launches the matching tool when the detail popup is disabled
    readonly property var metricApps: ({
        cpu: "plasma-systemmonitor",
        gpu: "plasma-systemmonitor",
        ram: "plasma-systemmonitor",
        disk: "filelight",
        net: "systemsettings kcm_networkmanagement",
        bat: "systemsettings kcm_powerdevilprofilesconfig"
    })

    function metricClicked(type) {
        // Hover tooltips carry the detail; click popup is opt-in
        if (!sysPopupEnabled) {
            if (metricApps[type]) launchApp(metricApps[type])
            return
        }
        if (expanded && popupMode === "sys" && sysFocus === type) { expanded = false; return }
        sysFocus = type
        popupMode = "sys"
        expanded = true
    }

    // Helper: are any system metrics visible?
    property bool hasSysMetrics: showCpu || showGpu || showRam || showNet || showDisk || showUptime

    // Battery HTML (shared between left and right positions)
    function batItemHtml() {
        var bolt = ''
        if (showChargingIcon && batCharging) {
            if (faFont.status === FontLoader.Ready)
                bolt = ' <span style="font-family:\'' + faFont.name + '\'; color:#FFFFFF;">&#xf0e7;</span>'
            else
                bolt = ' <span style="color:#FFFFFF;">&#x26A1;</span>'
        }
        var batTimeStr = showBatTime && fmtBatTime() ? (' <span style="color:' + claudeDimHex + ';">' + fmtBatTime() + '</span>') : ''
        return '<b><span style="color:' + batHex + ';">' + metricLabel('BAT', batIconUnicode(), batHex) + fmtPct(batValue) + '</span>' + batTimeStr + '</b>' + bolt
    }

    function batSepHtml() {
        if (showBatSpacer)
            return '&nbsp;&nbsp;&nbsp;<span style="color:#888888;">&#x2502;</span>&nbsp;&nbsp;&nbsp;'
        var s = ''
        for (var i = 0; i < itemSpacing; i++) s += '&nbsp;'
        return s
    }

    // Panel item: label + value in a slot whose pixel width is reserved for the
    // widest possible value (maxValue), value right-aligned. Item width never
    // changes with digit count, so gaps between items stay constant.
    component MetricItem: Item {
        id: mi
        property string seg
        property string labelHtml
        property string valueHtml
        property string maxValue: ""  // plain-text widest value; "" = no reservation
        // Extra trailing gap in digit widths — for items whose value always sits
        // near max slot width (RAM, disk), so their gap matches the airier items
        property int extraDigits: 0
        width: miRow.width + extraDigits * miDigit.advanceWidth
        height: miRow.height
        TextMetrics {
            id: miMetrics
            font.pointSize: root.panelPt
            font.bold: true
            text: mi.maxValue
        }
        TextMetrics {
            id: miDigit
            font.pointSize: root.panelPt
            font.bold: true
            text: "0"
        }
        Row {
            id: miRow
            spacing: 0
            Text {
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                verticalAlignment: Text.AlignVCenter
                text: mi.labelHtml
            }
            Text {
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                verticalAlignment: Text.AlignVCenter
                // Left-aligned: number sits tight against its icon, reserved
                // slack goes to the right where it blends into the item gap
                horizontalAlignment: Text.AlignLeft
                width: Math.max(implicitWidth, Math.ceil(miMetrics.advanceWidth))
                text: mi.valueHtml
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: root.segHovered(mi.seg, mi)
            onExited: root.hoverSeg = ""
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) root.metricClicked(mi.seg)
                else root.launchApp(root.clickCommand)
            }
        }
    }

    // ── Panel view ──────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot
        Layout.preferredWidth: panelRow.implicitWidth + 24
        Layout.minimumWidth: panelRow.implicitWidth + 24
        onHeightChanged: if (height > 0) root.panelHeight = height

        TextMetrics {
            id: spacerMetrics
            font.pointSize: root.panelPt
            text: {
                var s = ""
                for (var i = 0; i < root.itemSpacing; i++) s += "\u00A0"
                return s
            }
        }

        Row {
            id: panelRow
            anchors.centerIn: parent
            spacing: 0

            // Battery on LEFT + separator
            Text {
                visible: root.showBat && root.batValue >= 0 && !root.batOnRight
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                verticalAlignment: Text.AlignVCenter
                text: root.batItemHtml() + (root.hasSysMetrics ? root.batSepHtml() : '')
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: root.segHovered("bat", parent)
                    onExited: root.hoverSeg = ""
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) root.metricClicked("bat")
                        else root.launchApp(root.clickCommand)
                    }
                }
            }

            // System metrics
            Row {
                spacing: spacerMetrics.width

                MetricItem {
                    visible: root.showCpu
                    seg: "cpu"
                    labelHtml: '<b><span style="color:' + root.cpuHex + ';">' + root.metricLabel('CPU', 'f2db', root.cpuHex, 'cpu') + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.cpuHex + ';">' + root.fmtPct(root.cpuValue)
                        + (root.showCpuTemp && root.cpuTemp > 0 ? ' ' + Math.round(root.cpuTemp) + '°' : '')
                        + root.trendArrow(root.cpuValue, root.prevCpuDisplay) + '</span></b>'
                    maxValue: root.maxPct
                        + (root.showCpuTemp && root.cpuTemp > 0 ? ' 99°' : '')
                        + (root.showTrendArrows ? ' ↑' : '')
                }

                MetricItem {
                    visible: root.showGpu
                    seg: "gpu"
                    labelHtml: '<b><span style="color:' + root.gpuHex + ';">' + root.metricLabel('GPU', 'f625', root.gpuHex, 'gpu') + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.gpuHex + ';">' + root.fmtPct(root.gpuValue)
                        + (root.showGpuTemp && root.gpuTemp > 0 ? ' ' + Math.round(root.gpuTemp) + '°' : '')
                        + root.trendArrow(root.gpuValue, root.prevGpuDisplay) + '</span></b>'
                    maxValue: root.maxPct
                        + (root.showGpuTemp && root.gpuTemp > 0 ? ' 99°' : '')
                        + (root.showTrendArrows ? ' ↑' : '')
                }

                MetricItem {
                    visible: root.showRam
                    seg: "ram"
                    labelHtml: '<b><span style="color:' + root.ramHex + ';">' + root.metricLabel('RAM', 'f538', root.ramHex, 'ram') + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.ramHex + ';">' + root.fmtRam()
                        + root.trendArrow(root.ramValue, root.prevRamDisplay) + '</span></b>'
                    maxValue: (root.ramShowGB ? '99.9GB' : root.maxPct)
                        + (root.showTrendArrows ? ' ↑' : '')
                    extraDigits: 2
                }

                MetricItem {
                    visible: root.showDisk
                    seg: "disk"
                    labelHtml: '<b><span style="color:' + root.diskHex + ';">' + root.metricLabel('DISK', 'f0a0', root.diskHex, 'disk') + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.diskHex + ';">' + root.fmtPct(root.diskValue) + '</span></b>'
                    maxValue: root.maxPct
                    extraDigits: 1
                }

                MetricItem {
                    visible: root.showUptime
                    seg: "uptime"
                    labelHtml: '<b><span style="color:' + root.uptimeHex + ';">' + root.metricLabel('UP', 'f017', root.uptimeHex, 'uptime') + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.uptimeHex + ';">' + root.fmtUptime(root.uptimeSecs) + '</span></b>'
                    extraDigits: 1
                }

                MetricItem {
                    visible: root.showNet
                    seg: "net"
                    labelHtml: '<b><span style="color:' + root.netHex + ';">'
                        + root.metricLabel('NET', root.netConnected ? 'f019' : 'f071', root.netHex,
                            root.netConnected ? 'net' : undefined) + '</span></b>'
                    valueHtml: '<b><span style="color:' + root.netHex + ';">'
                        + (root.netConnected ? root.fmtNetSpeed(root.netDownBytes) : 'OFF') + '</span></b>'
                    maxValue: '999.9M/s'
                }

                Text {
                    visible: root.showClaude
                    textFormat: Text.RichText
                    font.pointSize: root.panelPt
                    verticalAlignment: Text.AlignVCenter
                    text: root.claudeItemHtml()
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.segHovered("ai", parent)
                        onExited: root.hoverSeg = ""
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.MiddleButton) root.launchApp("xdg-open https://claude.ai/settings/usage")
                            else root.togglePopup("claude")
                        }
                    }
                }

                Text {  // soft divider between AI segments
                    visible: root.showClaude && root.showCodex
                    textFormat: Text.RichText
                    font.pointSize: root.panelPt
                    verticalAlignment: Text.AlignVCenter
                    text: '<span style="color:#45484D;">&#x2502;</span>'
                }

                Text {
                    visible: root.showCodex
                    textFormat: Text.RichText
                    font.pointSize: root.panelPt
                    verticalAlignment: Text.AlignVCenter
                    text: root.codexItemHtml()
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: root.segHovered("ai", parent)
                        onExited: root.hoverSeg = ""
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.MiddleButton) root.launchApp("xdg-open https://chatgpt.com/codex/settings/usage")
                            else root.togglePopup("claude")
                        }
                    }
                }

                Text {  // today's local spend
                    visible: root.showCostPanel && root.ccToday() !== null
                    textFormat: Text.RichText
                    font.pointSize: root.panelPt
                    verticalAlignment: Text.AlignVCenter
                    text: {
                        var t = root.ccToday()
                        if (!t) return ""
                        return '<b><span style="color:' + root.claudeDimHex + ';">$</span><span style="color:#E8EAED;">'
                            + Math.round(t.totalCost || 0) + '</span></b>'
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePopup("claude")
                    }
                }
            }

            // Separator + Battery on RIGHT
            Text {
                visible: root.showBat && root.batValue >= 0 && root.batOnRight
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                verticalAlignment: Text.AlignVCenter
                text: (root.hasSysMetrics ? root.batSepHtml() : '') + root.batItemHtml()
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: root.segHovered("bat", parent)
                    onExited: root.hoverSeg = ""
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) root.metricClicked("bat")
                        else root.launchApp(root.clickCommand)
                    }
                }
            }
        }
    }

    // ── Popup view ──────────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth: popupLayout.implicitWidth + 44
        implicitHeight: popupLayout.implicitHeight + 44
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

        ColumnLayout {
            id: popupLayout
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 12

            // ── System detail (only non-redundant info; panel already shows live metrics) ──
            Text {
                visible: root.popupMode === "sys" && root.sysFocus === "bat" && root.batValue >= 0
                textFormat: Text.RichText
                text: '<span style="font-size:12pt;"><b><span style="color:' + root.batHex + ';">Battery ' + root.fmt(root.batValue) + '%</span></b>'
                    + (root.fmtBatTime() ? '<span style="color:#FFFFFF;">  ' + root.fmtBatTime() + (root.batCharging ? ' to full' : ' left') + '</span>' : '')
                    + (root.batPowerNow > 0 ? '<span style="color:' + root.claudeDimHex + ';">  &#183;  ' + (root.batPowerNow / 1000000).toFixed(1) + 'W draw</span>' : '')
                    + '</span>'
            }

            RowLayout {
                visible: root.popupMode === "sys" && root.sysFocus === "disk" && root.diskTotalG > 0
                spacing: 10
                Text { text: "Storage"; color: "#FFFFFF"; font.pointSize: 11; Layout.preferredWidth: 70 }
                Item {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 8
                    Rectangle { anchors.fill: parent; radius: 2; color: "#22FFFFFF" }
                    Rectangle {
                        width: parent.width * Math.min(root.diskValue, 100) / 100
                        height: parent.height
                        radius: 2
                        color: root.diskValue >= 90 ? root.claudeCritHex : root.diskHex
                    }
                }
                Text {
                    text: root.diskUsedG + "G / " + root.diskTotalG + "G  (" + Math.round(root.diskValue) + "%)"
                    color: root.claudeDimHex
                    font.pointSize: 10
                }
            }
            Text {
                visible: root.popupMode === "sys" && root.sysFocus === "uptime" && root.uptimeSecs > 0
                color: root.claudeDimHex
                font.pointSize: 10
                text: "Booted " + Qt.formatDateTime(new Date(Date.now() - root.uptimeSecs * 1000), "ddd MMM d, h:mm AP")
                    + "  ·  up " + root.fmtUptime(root.uptimeSecs)
            }

            Rectangle {
                visible: false
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                height: 1
                color: "#33888888"
            }
            ProcTable {
                visible: root.popupMode === "sys" && ["cpu", "gpu", "ram", "net"].indexOf(root.sysFocus) >= 0 && root.topProcs.length > 0
                title: "Top activity"
                procs: root.topProcs
            }
            Rectangle {
                visible: false
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                height: 1
                color: "#33888888"
            }
            ProcTable {
                visible: root.popupMode === "sys" && ["cpu", "gpu", "ram", "net"].indexOf(root.sysFocus) >= 0 && root.topApps.length > 0
                title: "Top apps"
                procs: root.topApps
            }

            // ── Claude usage section ──
            Text {
                visible: root.popupMode === "claude"
                textFormat: Text.RichText
                text: root.claudeIconHtml()
                    + ' <b style="font-size:13pt; color:' + root.claudeIconHex + ';">Claude</b>'
                    + (root.claudePlan ? '&nbsp;&nbsp;<span style="color:' + root.claudeDimHex + ';">' + root.claudePlan
                        + (root.claudeTier ? ' (' + root.claudeTier + ')' : '') + '</span>' : '')
            }
            Text {
                visible: root.popupMode === "claude" && root.claudeStale
                textFormat: Text.RichText
                text: '<span style="color:' + root.claudeWarnHex + ';">&#x26A0; cached data — ' + root.claudeError + '</span>'
            }
            Rectangle {
                id: fableAlertBanner
                property var limit: root.fableLimit()
                property string alertState: root.fableAlertState(fableAlertBanner.limit)
                property bool reportedOut: root.fableAccessActive()
                property bool dimmed: root.claudeStale && !fableAlertBanner.reportedOut
                visible: root.popupMode === "claude" && fableAlertBanner.alertState !== ""
                Layout.fillWidth: true
                Layout.preferredWidth: 480
                implicitHeight: fableAlertColumn.implicitHeight + 20
                radius: 6
                color: fableAlertBanner.reportedOut ? "#30EF5350"
                    : (fableAlertBanner.dimmed ? "#168A8A8A"
                        : (fableAlertBanner.alertState === "exhausted" ? "#30EF5350" : "#26FF9E45"))
                border.width: 1
                border.color: fableAlertBanner.reportedOut ? root.claudeCritHex
                    : (fableAlertBanner.dimmed ? root.claudeDimHex
                        : (fableAlertBanner.alertState === "exhausted"
                            ? root.claudeCritHex : root.claudeWarnHex))

                Column {
                    id: fableAlertColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 3

                    Text {
                        width: parent.width
                        color: fableAlertBanner.reportedOut ? root.claudeCritHex
                            : (fableAlertBanner.dimmed ? root.claudeDimHex
                            : (fableAlertBanner.alertState === "exhausted"
                                ? root.claudeCritHex : root.claudeWarnHex)
                            )
                        font.pointSize: 11
                        font.bold: true
                        text: fableAlertBanner.reportedOut
                            ? "⚠ Fable 5 included access is out until the weekly reset"
                            : (fableAlertBanner.alertState === "exhausted"
                                ? "⚠ Fable 5 included limit reached" + (fableAlertBanner.dimmed ? " (cached)" : "")
                                : "⚠ Fable 5 included usage is low" + (fableAlertBanner.dimmed ? " (cached)" : ""))
                    }
                    Text {
                        width: parent.width
                        color: fableAlertBanner.dimmed ? root.claudeDimHex : "#FFFFFF"
                        font.pointSize: 10
                        wrapMode: Text.WordWrap
                        text: root.fableAlertDetail(fableAlertBanner.limit)
                    }
                }
            }
            Repeater {
                model: root.popupMode === "claude" ? root.claudeLimits : []
                LimitRow {
                    label: root.claudeLimitLabel(modelData)
                    pct: modelData.percent
                    barColor: root.claudeLimitColor(modelData)
                    resetTxt: root.claudeFmtReset(modelData.resets_at)
                    resetColor: root.claudeResetHex
                }
            }
            RowLayout {
                visible: root.popupMode === "claude" && root.claudeHist.length > 1
                spacing: 10
                Canvas {
                    id: claudeSpark
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 30
                    width: 240; height: 30
                    property var pts: root.claudeHist
                    onPtsChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#33888888"
                        ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(0, height - 1); ctx.lineTo(width, height - 1); ctx.stroke()
                        var now = Date.now() / 1000, from = now - 86400
                        ctx.strokeStyle = root.claudeOkHex
                        ctx.lineWidth = 1.5
                        ctx.beginPath()
                        var started = false
                        for (var i = 0; i < pts.length; i++) {
                            if (pts[i].t < from) continue
                            var x = (pts[i].t - from) / 86400 * width
                            var y = height - 2 - (pts[i].p / 100) * (height - 4)
                            if (!started) { ctx.moveTo(x, y); started = true } else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
                Text { color: root.claudeDimHex; font.pointSize: 8; text: "5h window, last 24h" }
            }
            // ── Codex section ──
            Rectangle {
                visible: root.popupMode === "claude" && root.showCodex
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: "#33888888"
            }
            Text {
                visible: root.popupMode === "claude" && root.showCodex
                textFormat: Text.RichText
                text: root.codexIconHtml()
                    + ' <b style="font-size:13pt; color:' + root.codexIconHex + ';">Codex</b>'
                    + (root.codexPlan ? '&nbsp;&nbsp;<span style="color:' + root.claudeDimHex + ';">' + root.codexPlan + '</span>' : '')
                    + (root.codexFetchedAt ? '&nbsp;&nbsp;<span style="color:' + root.claudeDimHex + ';">updated ' + root.codexAge() + '</span>' : '')
            }
            Text {
                visible: root.popupMode === "claude" && root.showCodex && !root.codexWeekly && !root.codexSession
                color: root.claudeDimHex
                text: "No codex data"
            }
            Repeater {
                model: root.popupMode === "claude" && root.showCodex ? root.codexRowsList() : []
                LimitRow {
                    label: modelData.label
                    pct: modelData.pct
                    barColor: root.codexPctColor(modelData.pct)
                    resetTxt: root.fmtEpochReset(modelData.resets_at)
                    resetColor: root.codexResetHex
                }
            }
            RowLayout {
                visible: root.popupMode === "claude" && root.showCodex && root.codexHist.length > 1
                spacing: 10
                Canvas {
                    Layout.preferredWidth: 240
                    Layout.preferredHeight: 30
                    width: 240; height: 30
                    property var pts: root.codexHist
                    onPtsChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = "#33888888"
                        ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(0, height - 1); ctx.lineTo(width, height - 1); ctx.stroke()
                        var now = Date.now() / 1000, from = now - 86400
                        ctx.strokeStyle = root.codexOkHex
                        ctx.lineWidth = 1.5
                        ctx.beginPath()
                        var started = false
                        for (var i = 0; i < pts.length; i++) {
                            if (pts[i].t < from) continue
                            var x = (pts[i].t - from) / 86400 * width
                            var y = height - 2 - (pts[i].p / 100) * (height - 4)
                            if (!started) { ctx.moveTo(x, y); started = true } else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }
                Text { color: root.claudeDimHex; font.pointSize: 8; text: "7d window, last 24h" }
            }

            // ── Local spend (Claude Code logs — includes any routed models) ──
            Rectangle {
                visible: root.popupMode === "claude" && root.ccusageEnabled
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: "#33888888"
            }
            Text {
                visible: root.popupMode === "claude" && root.ccusageEnabled
                textFormat: Text.RichText
                text: '<b style="font-size:13pt; color:#B0BEC5;">Local spend</b>'
                    + '&nbsp;&nbsp;<span style="color:' + root.claudeDimHex + ';">this machine, all models in Claude Code logs</span>'
            }
            Text {
                visible: root.popupMode === "claude" && root.ccusageEnabled && root.ccToday() === null
                color: root.claudeDimHex
                text: root.ccRunning ? "Loading local stats…" : "No local stats"
            }
            GridLayout {
                visible: root.popupMode === "claude" && root.ccusageEnabled && root.ccToday() !== null
                columns: 2
                columnSpacing: 26
                rowSpacing: 3
                Text { text: "Today"; color: "#FFFFFF"; font.bold: true; font.pointSize: 10 }
                Text {
                    color: "#FFFFFF"; font.pointSize: 10
                    text: {
                        var t = root.ccToday()
                        return t ? "$" + (t.totalCost || 0).toFixed(2) + "  ·  " + root.fmtTokens(t.totalTokens || 0) + " tokens" : ""
                    }
                }
                Text { text: "Last 7 days"; color: "#FFFFFF"; font.bold: true; font.pointSize: 10 }
                Text {
                    color: "#FFFFFF"; font.pointSize: 10
                    text: {
                        var r = root.ccRange(7)
                        return "$" + r.cost.toFixed(2) + "  ·  " + root.fmtTokens(r.tokens) + " tokens"
                    }
                }
                Text { text: "Last 30 days"; color: "#FFFFFF"; font.bold: true; font.pointSize: 10 }
                Text {
                    color: "#FFFFFF"; font.pointSize: 10
                    text: {
                        var r = root.ccRange(30)
                        return "$" + r.cost.toFixed(2) + "  ·  " + root.fmtTokens(r.tokens) + " tokens"
                    }
                }
            }
            ColumnLayout {
                visible: root.popupMode === "claude" && root.ccusageEnabled && root.ccToday() !== null
                spacing: 1
                Repeater {
                    model: root.ccToday() ? (root.ccToday().modelBreakdowns || []) : []
                    Text {
                        color: root.claudeDimHex
                        font.pointSize: 9
                        text: "    " + modelData.modelName + ": $" + (modelData.cost || 0).toFixed(2)
                    }
                }
            }

            // ── Footer: check button + freshness ──
            Rectangle {
                visible: root.popupMode === "claude"
                Layout.fillWidth: true
                Layout.topMargin: 4
                height: 1
                color: "#33888888"
            }
            RowLayout {
                visible: root.popupMode === "claude"
                Layout.fillWidth: true
                spacing: 12

                PlasmaComponents.Button {
                    text: root.checking ? "Checking…" : "Check now"
                    icon.name: "view-refresh"
                    enabled: !root.checking
                    onClicked: root.forceCheck()
                }
                Item { Layout.fillWidth: true }
                Text {
                    color: root.claudeDimHex
                    font.pointSize: 8
                    text: "Claude updated " + root.fmtAgo(root.claudeFetchedAt)
                }
            }
        }
    }

    // ── Launch command data source ────────────────────────────────
    PlasmaSupport.DataSource {
        id: launchSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) {
                disconnectSource(source)
            }
        }
    }

    // ── CPU data source ─────────────────────────────────────────
    PlasmaSupport.DataSource {
        id: cpuSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                parseCpuData(output)
            }
        }
    }

    function parseCpuData(line) {
        var parts = line.split(/\s+/)
        if (parts.length < 5) return

        var user    = parseInt(parts[1]) || 0
        var nice    = parseInt(parts[2]) || 0
        var system  = parseInt(parts[3]) || 0
        var idle    = parseInt(parts[4]) || 0
        var iowait  = parseInt(parts[5]) || 0
        var irq     = parseInt(parts[6]) || 0
        var softirq = parseInt(parts[7]) || 0
        var steal   = parseInt(parts[8]) || 0

        var totalIdle = idle + iowait
        var total = user + nice + system + idle + iowait + irq + softirq + steal

        if (!cpuFirstRun) {
            var diffIdle = totalIdle - prevCpuIdle
            var diffTotal = total - prevCpuTotal
            if (diffTotal > 0) {
                prevCpuDisplay = cpuValue
                cpuValue = 100.0 * (1.0 - diffIdle / diffTotal)
            }
        }

        cpuFirstRun = false
        prevCpuIdle = totalIdle
        prevCpuTotal = total
    }

    // ── RAM data source ─────────────────────────────────────────
    PlasmaSupport.DataSource {
        id: ramSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                parseRamData(output)
            }
        }
    }

    function parseRamData(output) {
        var lines = output.split("\n")
        var memTotal = 0
        var memAvailable = 0
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(/\s+/)
            if (parts[0] === "MemTotal:")     memTotal = parseInt(parts[1]) || 0
            if (parts[0] === "MemAvailable:") memAvailable = parseInt(parts[1]) || 0
        }
        if (memTotal > 0) {
            var used = memTotal - memAvailable
            prevRamDisplay = ramValue
            ramValue = 100.0 * used / memTotal
            ramUsedGB = used / 1024.0 / 1024.0
            ramTotalGB = memTotal / 1024.0 / 1024.0
        }
    }

    // ── GPU sensor (native KSystemStats binding) ───────────────
    Sensors.Sensor {
        id: gpuSensor
        sensorId: "gpu/gpu1/usage"
        enabled: true
        onValueChanged: {
            var val = parseFloat(value)
            if (!isNaN(val)) {
                prevGpuDisplay = gpuValue
                gpuValue = val
            }
        }
    }

    // ── Temperature data source ──────────────────────────────────
    PlasmaSupport.DataSource {
        id: tempSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                parseTempData(output)
            }
        }
    }

    function parseTempData(output) {
        var parts = output.split(/\s+/)
        if (parts.length >= 1) {
            var ct = parseFloat(parts[0])
            if (!isNaN(ct)) cpuTemp = ct
        }
        if (parts.length >= 2) {
            var gt = parseFloat(parts[1])
            if (!isNaN(gt)) gpuTemp = gt
        }
    }

    // ── Network data source ──────────────────────────────────────
    PlasmaSupport.DataSource {
        id: netSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                parseNetData(output)
            }
        }
    }

    function parseNetData(output) {
        var parts = output.split("|")
        var totalRx = parseFloat(parts[0]) || 0
        var totalTx = parseFloat(parts[1]) || 0
        // Only trust an explicit 0/1 — empty or garbled output (failed poll)
        // must not flash the item to "OFF"
        var st = (parts[2] || "").trim()
        if (st === "0" || st === "1") netConnected = (st === "1")
        if (!netFirstRun) {
            var dr = totalRx - prevNetRxBytes
            var dt = totalTx - prevNetTxBytes
            var secs = effectiveIntervalMs / 1000.0
            if (dr >= 0) netDownBytes = dr / secs
            if (dt >= 0) netUpBytes = dt / secs
        }
        prevNetRxBytes = totalRx
        prevNetTxBytes = totalTx
        netFirstRun = false
    }

    // ── Disk data source ─────────────────────────────────────────
    PlasmaSupport.DataSource {
        id: diskSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                var f = output.split(/\s+/)
                diskValue = parseInt(f[0]) || 0
                if (f.length >= 3) {
                    diskTotalG = parseInt(f[1]) || 0
                    diskUsedG = parseInt(f[2]) || 0
                }
            }
        }
    }

    // ── Uptime data source ───────────────────────────────────────
    PlasmaSupport.DataSource {
        id: uptimeSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                var val = parseFloat(output) || 0
                uptimeSecs = val
            }
        }
    }

    // ── Battery hover info (brightness + charge thresholds) ─────
    PlasmaSupport.DataSource {
        id: batInfoSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var lines = (buffers[source] || "").trim().split("\n")
                delete buffers[source]
                disconnectSource(source)
                var cur = parseInt(lines[0]), max = parseInt(lines[1])
                screenBrightPct = (max > 0) ? Math.round(cur / max * 100) : -1
                kbdBrightLevel = parseInt(lines[2]) || 0
                kbdBrightMax = parseInt(lines[3]) || 0
                batStartThreshold = parseInt(lines[4]) || 0
            }
        }
    }

    // ── Battery data source ─────────────────────────────────────
    PlasmaSupport.DataSource {
        id: batSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                var parts = output.split("|")
                var capStr = parts[0] || "-1"
                var acStr = (parts[1] || "0").trim()
                var enNow = (parts[2] || "0").trim()
                var enFull = (parts[3] || "0").trim()
                var pwNow = (parts[4] || "0").trim()
                if (capStr !== "" && capStr !== "-1") {
                    var val = parseFloat(capStr)
                    if (!isNaN(val)) {
                        batValue = val
                    }
                } else {
                    batValue = -1
                }
                batCharging = (acStr === "1")
                batEnergyNow = (parseFloat(enNow) || 0) / 1000000.0
                batEnergyFull = (parseFloat(enFull) || 0) / 1000000.0
                batPowerNow = (parseFloat(pwNow) || 0) / 1000000.0
                var clStr = (parts[5] || "100").trim()
                var clVal = parseInt(clStr)
                if (!isNaN(clVal) && clVal > 0 && clVal <= 100)
                    batChargeLimit = clVal
                else
                    batChargeLimit = 100
            }
        }
    }

    // ── Claude usage data sources ───────────────────────────────
    readonly property string claudeScriptPath: {
        var p = Qt.resolvedUrl("../scripts/fetch-usage.sh").toString()
        return p.replace(/^file:\/\//, "")
    }

    PlasmaSupport.DataSource {
        id: claudeSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                parseClaudeUsage(output)
            }
        }
    }

    function parseClaudeUsage(output) {
        checking = false
        var obj
        try { obj = JSON.parse(output) } catch (e) {
            claudeStale = true; claudeError = "bad output"; return
        }
        if (!obj.ok) {
            claudeStale = true
            claudeError = obj.error || "unknown"
            return
        }
        var u = obj.usage || {}
        var newLimits = []
        if (u.limits && u.limits.length) {
            for (var i = 0; i < u.limits.length; i++) {
                var l = u.limits[i]
                if (l.kind === "session" || l.kind === "weekly_all" || l.kind === "weekly_scoped")
                    newLimits.push(l)
            }
        } else {
            if (u.five_hour) newLimits.push({kind: "session", percent: u.five_hour.utilization, resets_at: u.five_hour.resets_at})
            if (u.seven_day) newLimits.push({kind: "weekly_all", percent: u.seven_day.utilization, resets_at: u.seven_day.resets_at})
        }
        // This local Claude Code signal records actual Fable denial. Set it
        // before classification so it can override a lagging API percentage.
        if (u.extra_usage && u.extra_usage.is_enabled !== undefined)
            claudePaidUsageEnabled = u.extra_usage.is_enabled === true
        claudeFableAccess = obj.fable_access || ({})
        // Desktop alerts are boundary events only: no Fable low/warning alert.
        // Fresh API meters baseline silently, then notify once at 100% used and
        // once when a previously-used meter resets to exactly 0%.
        var fableReportedOut = fableAccessActive()
        var selectedFable = fableLimitFrom(newLimits)
        for (var k = 0; k < newLimits.length; k++) {
            var meter = newLimits[k]
            var meterIsFable = isFableLimit(meter)
            if (meterIsFable || obj.stale === true) continue
            var meterTerminal = claudeLimitTerminal(meter)
            observeUsageMeter(claudeMeterId(meter),
                "Claude " + claudeLimitLabel(meter), meter.percent, meter.resets_at,
                meterTerminal,
                meterTerminal ? usageUnavailableDetail("Claude", meter.resets_at) : "")
        }
        // Select exactly one scoped Fable row. Multiple API rows must never
        // fight over the canonical state key within the same poll.
        if (selectedFable && (obj.stale !== true || fableReportedOut))
        {
            var fableTerminal = claudeLimitTerminal(selectedFable)
            observeUsageMeter("claude:weekly_scoped:fable", "Fable 5 allowance",
                selectedFable.percent, fableEffectiveReset(selectedFable),
                fableReportedOut || fableTerminal,
                fableReportedOut ? fableAlertDetail(selectedFable, false)
                    : (fableTerminal
                        ? usageUnavailableDetail("Claude", fableEffectiveReset(selectedFable)) : ""))
        }
        else if (fableReportedOut)
            observeUsageMeter("claude:weekly_scoped:fable", "Fable 5 allowance",
                100, fableEffectiveReset(null), true, fableAlertDetail(null, false))
        else if (obj.stale !== true
                && !usageNotificationState.meters["claude:weekly_scoped:fable"]) {
            var weeklyForFable = null
            for (var wk = 0; wk < newLimits.length; wk++)
                if (newLimits[wk].kind === "weekly_all") weeklyForFable = newLimits[wk]
            observeUsageMeter("claude:weekly_scoped:fable", "Fable 5 allowance",
                0, weeklyForFable ? weeklyForFable.resets_at : "", false, "")
        }
        flushUsageNotificationState()

        claudeLimits = newLimits
        claudePlan = obj.plan || ""
        claudeTier = obj.tier || ""
        claudeFetchedAt = obj.fetched_at || claudeFetchedAt
        // Transient failures (429 bursts etc.) serve cache with stale:true;
        // only gray out once data is >10 min old, so the panel doesn't flicker.
        claudeStale = obj.stale === true && (Date.now() / 1000 - claudeFetchedAt) > 600
        claudeError = obj.stale === true ? (obj.error || "") : ""
    }

    PlasmaSupport.DataSource {
        id: ccusageSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                root.ccRunning = false
                try {
                    var obj = JSON.parse(output)
                    root.ccDaily = obj.daily || []
                    root.ccFetchedAt = Date.now()
                } catch (e) { /* keep old data */ }
            }
        }
    }

    function refreshClaude() {
        if (showClaude)
            claudeSource.connectSource("bash " + claudeScriptPath)
        if (showCostPanel)
            refreshCcusage()
        if (showCodex)
            codexSource.connectSource("bash " + claudeScriptPath.replace("fetch-usage.sh", "fetch-codex.sh"))
    }

    PlasmaSupport.DataSource {
        id: codexSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "").trim()
                delete buffers[source]
                disconnectSource(source)
                try {
                    var obj = JSON.parse(output)
                    if (obj.ok) {
                        root.codexWeekly = obj.weekly || null
                        root.codexSession = obj.session5h || null
                        root.codexPlan = obj.plan || ""
                        root.codexFeatures = obj.features || []
                        if (obj.session5h && root.usageSampleFresh(obj.session5h.fetched_at))
                            root.observeUsageMeter("codex:session5h", "Codex Session (5h)",
                                obj.session5h.used_percent, obj.session5h.resets_at, false, "")
                        var weeklyFresh = obj.weekly && root.usageSampleFresh(obj.weekly.fetched_at)
                        if (weeklyFresh)
                        {
                            var weeklyTerminal = obj.weekly.limit_reached === true
                                || obj.weekly.allowed === false
                            root.observeUsageMeter("codex:weekly", "Codex Weekly",
                                obj.weekly.used_percent, obj.weekly.resets_at,
                                weeklyTerminal, weeklyTerminal
                                    ? root.usageUnavailableDetail("Codex", obj.weekly.resets_at) : "")
                        }
                        var features = obj.features || []
                        for (var i = 0; weeklyFresh && i < features.length; i++) {
                            var feature = features[i]
                            var featureKey = feature.metered_feature || feature.name
                            var featureTerminal = feature.limit_reached === true
                                || feature.allowed === false
                            root.observeUsageMeter("codex:feature:" + root.usageMeterSlug(featureKey),
                                "Codex " + (feature.name || "feature"), feature.used_percent,
                                feature.resets_at, featureTerminal, featureTerminal
                                    ? root.usageUnavailableDetail("Codex", feature.resets_at) : "")
                        }
                        root.flushUsageNotificationState()
                    }
                } catch (e) { /* keep old data */ }
            }
        }
    }

    function refreshCcusage() {
        if (!showClaude || !ccusageEnabled || ccRunning) return
        if (Date.now() - ccFetchedAt < 30 * 60 * 1000) return
        var d = new Date(Date.now() - 29 * 86400000)
        var since = "" + d.getFullYear()
            + ("0" + (d.getMonth() + 1)).slice(-2)
            + ("0" + d.getDate()).slice(-2)
        ccRunning = true
        ccusageSource.connectSource(ccusagePath + " daily --json --since " + since)
    }

    PlasmaSupport.DataSource {
        id: histSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "")
                delete buffers[source]
                disconnectSource(source)
                parseHist(output)
            }
        }
    }

    function parseHist(output) {
        var lines = output.split("\n")
        var mode = "", ch = [], xh = []
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i].trim()
            if (ln === "CLAUDE") { mode = "c"; continue }
            if (ln === "CODEX") { mode = "x"; continue }
            if (!ln) continue
            var f = ln.split("\t")
            var t = parseInt(f[0]); var pv = parseFloat(f[1])
            if (isNaN(t) || isNaN(pv)) continue
            if (mode === "c") ch.push({t: t, p: pv})
            else if (mode === "x") xh.push({t: t, p: pv})
        }
        claudeHist = ch
        codexHist = xh
    }

    function refreshHist() {
        var c = "${XDG_CACHE_HOME:-$HOME/.cache}"
        histSource.connectSource("sh -c 'echo CLAUDE; tail -n 1500 " + c + "/claude-usage-history.tsv 2>/dev/null; echo CODEX; tail -n 1500 " + c + "/codex-usage-history.tsv 2>/dev/null'")
    }

    PlasmaSupport.DataSource {
        id: procSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            var chunk = data["stdout"] || ""
            buffers[source] = (buffers[source] || "") + chunk
            if (data["exit code"] !== undefined) {
                var output = (buffers[source] || "")
                delete buffers[source]
                disconnectSource(source)
                var sysNames = ["java", "plasma", "kwin", "systemd", "pipewire", "wireplumber",
                    "xwayland", "kded", "kio", "dbus", "baloo", "krunner", "kglobalaccel",
                    "polkit", "rtkit", "packagekit", "ksystemstats", "kaccess", "xdg-",
                    "sd-pam", "gjs", "at-spi", "gvfs", "kernel", "kworker", "ps", "spectacle"]
                function isSystem(n) {
                    var ln = n.toLowerCase()
                    for (var k = 0; k < sysNames.length; k++)
                        if (ln.indexOf(sysNames[k]) === 0) return true
                    return false
                }
                // aggregate multi-process apps (chrome spawns one process per tab etc.)
                var rows = output.split("\n"), agg = {}
                for (var i = 1; i < rows.length; i++) {
                    var f = rows[i].trim().split(/\s+/)
                    if (f.length < 4) continue
                    var nm = f.slice(0, f.length - 3).join(" ")
                    var e = agg[nm] || {name: nm, cpu: 0, mem: 0, rss: 0, n: 0}
                    e.cpu += parseFloat(f[f.length - 3]) || 0
                    e.mem += parseFloat(f[f.length - 2]) || 0
                    e.rss += parseInt(f[f.length - 1]) || 0
                    e.n += 1
                    agg[nm] = e
                }
                var all = []
                for (var key in agg) all.push(agg[key])
                function disp(e) { return e.n > 1 ? e.name + " \u00D7" + e.n : e.name }
                function cpuRow(e) { return {name: disp(e), v1: e.cpu.toFixed(1) + "%", v2: e.mem.toFixed(1) + "%"} }
                function memRow(e) { return {name: disp(e), v1: e.mem.toFixed(1) + "%", v2: (e.rss / 1048576).toFixed(1) + "G"} }
                function pick(list, mk, excl) {
                    var out = []
                    for (var j = 0; j < list.length && out.length < 3; j++) {
                        if (excl && isSystem(list[j].name)) continue
                        out.push(mk(list[j]))
                    }
                    return out
                }
                all.sort(function(a, b) { return b.cpu - a.cpu })
                topProcs = pick(all, cpuRow, false)
                topApps = pick(all.filter(function(e) { return !isSystem(e.name) && topProcs.map(function(x){return x.name}).indexOf(disp(e)) < 0 }), cpuRow, false)
                all.sort(function(a, b) { return b.mem - a.mem })
                topMem = pick(all, memRow, false)
                topMemApps = pick(all.filter(function(e) { return !isSystem(e.name) && topMem.map(function(x){return x.name}).indexOf(disp(e)) < 0 }), memRow, false)
            }
        }
    }

    function refreshProcs() {
        procSource.connectSource("sh -c 'ps -eo comm,%cpu,%mem,rss --sort=-%cpu | head -60'")
    }

    onExpandedChanged: {
        if (root.expanded) {
            if (popupMode === "claude") {
                refreshClaude()
                refreshCcusage()
                refreshHist()
            } else {
                refreshProcs()
                // storage + boot info shown in the popup regardless of panel toggles
                diskSource.connectSource("sh -c \"df -BG / --output=pcent,size,used | tail -1 | tr -d '%G'\"")
                uptimeSource.connectSource("sh -c \"awk '{print \\$1}' /proc/uptime\"")
            }
        }
    }

    Timer {
        interval: root.claudeIntervalSec * 1000
        running: root.showClaude
        repeat: true
        onTriggered: root.refreshClaude()
    }

    // ── Timer (interval driven by config + battery mode) ─────────
    Timer {
        id: updateTimer
        interval: root.effectiveIntervalMs
        running: true
        repeat: true
        onTriggered: refreshAll()
    }

    function refreshAll() {
        if (showCpu)
            cpuSource.connectSource("head -1 /proc/stat")
        if (showRam)
            ramSource.connectSource("head -3 /proc/meminfo")
        if (showBat || batteryModeEnabled)
            batSource.connectSource("sh -c 'cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo -1); ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0); en=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo 0); ef=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo 0); pw=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0); cl=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 100); echo \"$cap|$ac|$en|$ef|$pw|$cl\"'")

        if (showCpuTemp || showGpuTemp) {
            tempSource.connectSource("sh -c 'ct=0; gt=0; for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); if [ \"$n\" = \"coretemp\" ]; then v=$(cat $d/temp1_input 2>/dev/null); [ -n \"$v\" ] && ct=$((v/1000)); fi; if [ \"$n\" = \"thinkpad\" ]; then v=$(cat $d/temp2_input 2>/dev/null); [ -n \"$v\" ] && gt=$((v/1000)); fi; done; echo \"$ct $gt\"'")
        }

        if (showNet) {
            netSource.connectSource("sh -c 'read rx tx <<< $(awk \"NR>2 && \\$1 !~ /lo:/{gsub(/:/,\\\"\\\",\\$1); r+=\\$2; t+=\\$10} END{print r+0, t+0}\" /proc/net/dev); up=0; grep -qx up /sys/class/net/*/operstate 2>/dev/null && up=1; echo \"$rx|$tx|$up\"'")
        }

        if (showDisk) {
            diskSource.connectSource("sh -c \"df -BG / --output=pcent,size,used | tail -1 | tr -d '%G'\"")
        }

        if (showUptime) {
            uptimeSource.connectSource("sh -c \"awk '{print \\$1}' /proc/uptime\"")
        }
    }

    Component.onCompleted: {
        loadUsageNotificationState()
        refreshAll()
        refreshClaude()
    }
}
