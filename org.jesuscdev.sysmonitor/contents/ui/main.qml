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
    property real uptimeSecs: 0.0
    property real batEnergyNow: 0.0
    property real batEnergyFull: 0.0
    property real batPowerNow: 0.0
    property int batChargeLimit: 100  // 0-100, from charge_control_end_threshold

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
    property var ccDaily: []
    property double ccFetchedAt: 0       // epoch ms
    property bool ccRunning: false

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
    readonly property string claudeIconHex: "#D97757"    // Claude orange
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
        if (l.kind === "weekly_scoped")
            return "Weekly " + ((l.scope && l.scope.model && l.scope.model.display_name) || "model")
        return l.kind
    }

    function claudeFmtReset(iso) {
        if (!iso) return ""
        var ms = new Date(iso).getTime() - Date.now()
        if (isNaN(ms) || ms <= 0) return "soon"
        var m = Math.floor(ms / 60000)
        var d = Math.floor(m / 1440)
        var h = Math.floor((m % 1440) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + (m % 60) + "m"
        return (m % 60) + "m"
    }

    function claudeIconHtml() {
        if (useIcons && faFont.status === FontLoader.Ready)
            return faIcon('f069', claudeIconHex)
        return '<span style="color:' + claudeIconHex + ';">&#x273B;</span> '
    }

    function claudeItemHtml() {
        var s = claudeLimitByKind("session")
        var w = claudeLimitByKind("weekly_all")
        var parts = []
        if (s) parts.push('<span style="color:' + claudeResetHex + ';">5h </span>'
            + '<span style="color:' + claudePctColor(s.percent) + ';">' + fmtPct(s.percent) + '</span>')
        if (w) parts.push('<span style="color:' + claudeResetHex + ';">7d </span>'
            + '<span style="color:' + claudePctColor(w.percent) + ';">' + fmtPct(w.percent) + '</span>')
        var body = parts.length ? parts.join('<span style="color:' + claudeDimHex + ';">&#183; </span>')
                                : '<span style="color:' + claudeDimHex + ';">…</span>'
        return '<b>' + claudeIconHtml() + body + '</b>'
    }

    function ccToday() {
        return ccDaily.length ? ccDaily[ccDaily.length - 1] : null
    }
    function ccWeekCost() {
        var sum = 0
        for (var i = 0; i < ccDaily.length; i++) sum += (ccDaily[i].totalCost || 0)
        return sum
    }
    function fmtTokens(n) {
        if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
        return "" + Math.round(n)
    }

    // ── Font Awesome icon helpers ─────────────────────────────────
    function faIcon(unicode, color) {
        return '<span style="font-family:\'' + faFont.name + '\'; color:' + color + ';">&#x' + unicode + ';</span> '
    }

    function metricLabel(text, iconUnicode, color) {
        if (useIcons && faFont.status === FontLoader.Ready)
            return faIcon(iconUnicode, color)
        return text + ' '
    }

    // Format helpers
    function fmt(val) {
        return useDecimals ? val.toFixed(1) : Math.round(val).toString()
    }

    // Right-pad percentage to fixed width (widest: "100%" or "100.0%")
    function fmtPct(val) {
        var str = fmt(val)
        var maxLen = useDecimals ? 5 : 3  // "100.0" or "100"
        var pad = maxLen - str.length
        var result = str + '%'
        for (var i = 0; i < pad; i++) result += '&nbsp;'
        return result
    }

    function fmtRam() {
        if (ramShowGB) {
            var str = ramUsedGB.toFixed(1) + 'GB'
            // Pad to 6 rendered chars (widest: "99.9GB")
            var pad = 6 - str.length
            for (var i = 0; i < pad; i++) str += '&nbsp;'
            return str
        }
        return fmtPct(ramValue)
    }

    function fmtNetSpeed(bytesPerSec) {
        var str
        if (bytesPerSec >= 1073741824) str = (bytesPerSec / 1073741824).toFixed(1) + 'G/s'
        else if (bytesPerSec >= 1048576) str = (bytesPerSec / 1048576).toFixed(1) + 'M/s'
        else str = (bytesPerSec / 1024).toFixed(0) + 'K/s'
        // Right-pad to 8 rendered chars (widest M/s: "999.9M/s") so bar width stays stable
        var pad = 8 - str.length
        for (var i = 0; i < pad; i++) str += '&nbsp;'
        return str
    }

    function fmtUptime(secs) {
        var d = Math.floor(secs / 86400)
        var h = Math.floor((secs % 86400) / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (d > 0) return d + 'd ' + h + 'h'
        if (h > 0) return h + 'h ' + m + 'm'
        return m + 'm&nbsp;'
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
        if (h > 0) return h + 'h' + (m > 0 ? m + 'm' : '')
        return m + 'm'
    }

    function trendArrow(current, previous) {
        if (!showTrendArrows) return ''
        var delta = current - previous
        if (delta > 2) return ' &#x2191;'   // up arrow
        if (delta < -2) return ' &#x2193;'  // down arrow
        return ''
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

    function metricClicked(type) {
        if (type === "cpu" || type === "gpu" || type === "ram" || type === "disk")
            launchApp(clickCommand)
        else if (type === "net")
            launchApp("kcmshell6 kcm_networkmanagement")
        else if (type === "uptime" || type === "bat")
            launchApp("kcmshell6 kcm_powerdevilprofilesconfig")
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
        var batTimeStr = showBatTime ? (' ' + fmtBatTime()) : ''
        return '<b><span style="color:' + batHex + ';">' + metricLabel('BAT', batIconUnicode(), batHex) + fmt(batValue) + '%' + batTimeStr + '</span></b>' + bolt
    }

    function batSepHtml() {
        if (showBatSpacer)
            return '&nbsp;&nbsp;&nbsp;<span style="color:#888888;">&#x2502;</span>&nbsp;&nbsp;&nbsp;'
        var s = ''
        for (var i = 0; i < itemSpacing; i++) s += '&nbsp;'
        return s
    }

    // ── Panel view ──────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot
        Layout.preferredWidth: panelRow.implicitWidth + 24
        Layout.minimumWidth: panelRow.implicitWidth + 24

        TextMetrics {
            id: spacerMetrics
            font.pointSize: 10
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
                font.pointSize: 10
                verticalAlignment: Text.AlignVCenter
                text: root.batItemHtml() + (root.hasSysMetrics ? root.batSepHtml() : '')
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) root.metricClicked("bat")
                        else root.togglePopup("sys")
                    }
                }
            }

            // System metrics
            Row {
                spacing: spacerMetrics.width

                Text {
                    visible: root.showCpu
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.cpuHex + ';">'
                        + root.metricLabel('CPU', 'f2db', root.cpuHex) + root.fmtPct(root.cpuValue)
                        + (root.showCpuTemp && root.cpuTemp > 0 ? ' ' + Math.round(root.cpuTemp) + '°' : '')
                        + root.trendArrow(root.cpuValue, root.prevCpuDisplay) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("cpu")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showGpu
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.gpuHex + ';">'
                        + root.metricLabel('GPU', 'f625', root.gpuHex) + root.fmtPct(root.gpuValue)
                        + (root.showGpuTemp && root.gpuTemp > 0 ? ' ' + Math.round(root.gpuTemp) + '°' : '')
                        + root.trendArrow(root.gpuValue, root.prevGpuDisplay) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("gpu")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showRam
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.ramHex + ';">'
                        + root.metricLabel('RAM', 'f538', root.ramHex) + root.fmtRam()
                        + root.trendArrow(root.ramValue, root.prevRamDisplay) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("ram")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showDisk
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.diskHex + ';">'
                        + root.metricLabel('DISK', 'f0a0', root.diskHex) + root.fmtPct(root.diskValue) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("disk")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showUptime
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.uptimeHex + ';">'
                        + root.metricLabel('UP', 'f017', root.uptimeHex) + root.fmtUptime(root.uptimeSecs) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("uptime")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showNet
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.netHex + ';">'
                        + root.metricLabel('NET', root.netConnected ? 'f019' : 'f071', root.netHex)
                        + (root.netConnected ? root.fmtNetSpeed(root.netDownBytes) : 'OFF') + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("net")
                            else root.togglePopup("sys")
                        }
                    }
                }

                Text {
                    visible: root.showClaude
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: root.claudeItemHtml()
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePopup("claude")
                    }
                }
            }

            // Separator + Battery on RIGHT
            Text {
                visible: root.showBat && root.batValue >= 0 && root.batOnRight
                textFormat: Text.RichText
                font.pointSize: 10
                verticalAlignment: Text.AlignVCenter
                text: (root.hasSysMetrics ? root.batSepHtml() : '') + root.batItemHtml()
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) root.metricClicked("bat")
                        else root.togglePopup("sys")
                    }
                }
            }
        }
    }

    // ── Popup view ──────────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth: popupLayout.implicitWidth + 40
        implicitHeight: popupLayout.implicitHeight + 40
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        ColumnLayout {
            id: popupLayout
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 10

            Text {
                visible: root.popupMode === "sys"
                textFormat: Text.RichText
                text: '<b style="font-size:14pt;">System Monitor</b>'
                color: "#FFFFFF"
            }
            Text {
                visible: root.popupMode === "sys" && root.showCpu
                textFormat: Text.RichText
                text: '<span style="color:' + root.cpuHex + '; font-size:12pt;"><b>CPU:  ' + root.fmt(root.cpuValue) + '%'
                    + (root.showCpuTemp && root.cpuTemp > 0 ? '  ' + Math.round(root.cpuTemp) + '°C' : '') + '</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showGpu
                textFormat: Text.RichText
                text: '<span style="color:' + root.gpuHex + '; font-size:12pt;"><b>GPU:  ' + root.fmt(root.gpuValue) + '%'
                    + (root.showGpuTemp && root.gpuTemp > 0 ? '  ' + Math.round(root.gpuTemp) + '°C' : '') + '</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showRam
                textFormat: Text.RichText
                text: '<span style="color:' + root.ramHex + '; font-size:12pt;"><b>RAM:  ' + root.fmtRam() + '</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showNet
                textFormat: Text.RichText
                text: '<span style="color:' + root.netHex + '; font-size:12pt;"><b>NET:  '
                    + (root.netConnected ? root.fmtNetSpeed(root.netDownBytes) : 'Disconnected') + '</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showDisk
                textFormat: Text.RichText
                text: '<span style="color:' + root.diskHex + '; font-size:12pt;"><b>DISK:  ' + root.fmt(root.diskValue) + '%</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showUptime
                textFormat: Text.RichText
                text: '<span style="color:' + root.uptimeHex + '; font-size:12pt;"><b>UP:  ' + root.fmtUptime(root.uptimeSecs) + '</b></span>'
            }
            Text {
                visible: root.popupMode === "sys" && root.showBat && root.batValue >= 0
                textFormat: Text.RichText
                text: '<span style="color:' + root.batHex + '; font-size:12pt;"><b>BAT:  ' + root.fmt(root.batValue) + '%'
                    + (root.showBatTime ? '  ' + root.fmtBatTime() : '') + '</b></span>'
                    + ((root.showChargingIcon && root.batCharging) ? ' <span style="font-family:\'' + faFont.name + '\'; color:#FFFFFF; font-size:12pt;">&#xf0e7;</span>' : '')
            }

            // ── Claude usage section ──
            Text {
                visible: root.popupMode === "claude"
                textFormat: Text.RichText
                text: root.claudeIconHtml()
                    + '<b style="font-size:12pt; color:' + root.claudeIconHex + ';">Claude</b>'
                    + (root.claudePlan ? ' <span style="color:' + root.claudeDimHex + ';">' + root.claudePlan
                        + (root.claudeTier ? ' (' + root.claudeTier + ')' : '') + '</span>' : '')
            }
            Text {
                visible: root.popupMode === "claude" && root.claudeStale
                textFormat: Text.RichText
                text: '<span style="color:' + root.claudeWarnHex + ';">&#x26A0; cached data — ' + root.claudeError + '</span>'
            }
            Repeater {
                model: root.popupMode === "claude" ? root.claudeLimits : []
                Text {
                    textFormat: Text.RichText
                    text: '<span style="font-size:12pt;"><span style="color:#FFFFFF;">' + root.claudeLimitLabel(modelData) + ':  </span>'
                        + '<b><span style="color:' + root.claudePctColor(modelData.percent) + ';">' + Math.round(modelData.percent) + '%</span></b>'
                        + '  <span style="color:' + root.claudeResetHex + ';">&#x21BB; ' + root.claudeFmtReset(modelData.resets_at) + '</span></span>'
                }
            }
            Text {
                visible: root.popupMode === "claude" && root.ccusageEnabled
                textFormat: Text.RichText
                text: {
                    var t = root.ccToday()
                    if (!t) return '<span style="color:' + root.claudeDimHex + ';">' + (root.ccRunning ? 'Loading local stats…' : 'No local stats') + '</span>'
                    var lines = '<span style="color:#FFFFFF;"><b>Today:</b> $' + (t.totalCost || 0).toFixed(2)
                        + ' &#183; ' + root.fmtTokens(t.totalTokens || 0) + ' tokens'
                        + '<br><b>Last 7 days:</b> $' + root.ccWeekCost().toFixed(2) + '</span>'
                    var mb = t.modelBreakdowns || []
                    for (var i = 0; i < mb.length; i++)
                        lines += '<br><span style="color:' + root.claudeDimHex + ';">&nbsp;&nbsp;' + mb[i].modelName + ': $' + (mb[i].cost || 0).toFixed(2) + '</span>'
                    return lines
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
        netConnected = (parts[1] || "0").trim() === "1"
        if (!netFirstRun) {
            var delta = totalRx - prevNetRxBytes
            if (delta >= 0) {
                var intervalSec = effectiveIntervalMs / 1000
                netDownBytes = delta / intervalSec
            }
        }
        netFirstRun = false
        prevNetRxBytes = totalRx
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
                var val = parseInt(output) || 0
                diskValue = val
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
    }

    function refreshCcusage() {
        if (!showClaude || !ccusageEnabled || ccRunning) return
        if (Date.now() - ccFetchedAt < 30 * 60 * 1000) return
        var d = new Date(Date.now() - 6 * 86400000)
        var since = "" + d.getFullYear()
            + ("0" + (d.getMonth() + 1)).slice(-2)
            + ("0" + d.getDate()).slice(-2)
        ccRunning = true
        ccusageSource.connectSource(ccusagePath + " daily --json --since " + since)
    }

    onExpandedChanged: {
        if (root.expanded) {
            refreshClaude()
            refreshCcusage()
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
            netSource.connectSource("sh -c 'rx=$(awk \"NR>2 && \\$1 !~ /lo:/{gsub(/:/,\\\"\\\",\\$1); sum+=\\$2} END{print sum+0}\" /proc/net/dev); up=0; for iface in /sys/class/net/*; do n=$(basename $iface); [ \"$n\" != \"lo\" ] && s=$(cat $iface/operstate 2>/dev/null); [ \"$s\" = \"up\" ] && up=1; done; echo \"$rx|$up\"'")
        }

        if (showDisk) {
            diskSource.connectSource("sh -c \"df / --output=pcent | tail -1 | tr -d ' %'\"")
        }

        if (showUptime) {
            uptimeSource.connectSource("sh -c \"awk '{print \\$1}' /proc/uptime\"")
        }
    }

    Component.onCompleted: {
        refreshAll()
        refreshClaude()
    }
}
