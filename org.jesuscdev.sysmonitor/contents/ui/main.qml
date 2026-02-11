import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as PlasmaSupport
import org.kde.plasma.components 3.0 as PlasmaComponents

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
    property string netHex: netColorOverride !== ""
        ? netColorOverride : (brightColors ? netHexBright : netHexNormal)
    property string diskHex: (warnEnabled && diskValue >= 90)
        ? warnHex : (diskColorOverride !== "" ? diskColorOverride : (brightColors ? diskHexBright : diskHexNormal))
    property string uptimeHex: uptimeColorOverride !== ""
        ? uptimeColorOverride : (brightColors ? uptimeHexBright : uptimeHexNormal)

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

    function fmtRam() {
        if (ramShowGB) return ramUsedGB.toFixed(1) + 'GB'
        return fmt(ramValue) + '%'
    }

    function fmtNetSpeed(bytesPerSec) {
        if (bytesPerSec >= 1073741824) return (bytesPerSec / 1073741824).toFixed(1) + 'G/s'
        if (bytesPerSec >= 1048576) return (bytesPerSec / 1048576).toFixed(1) + 'M/s'
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(0) + 'K/s'
        return Math.round(bytesPerSec) + 'B/s'
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
        return '<b><span style="color:' + batHex + ';">' + metricLabel('BAT', 'f240', batHex) + fmt(batValue) + '%' + batTimeStr + '</span></b>' + bolt
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
                        else root.expanded = !root.expanded
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
                        + root.metricLabel('CPU', 'f2db', root.cpuHex) + root.fmt(root.cpuValue) + '%'
                        + (root.showCpuTemp && root.cpuTemp > 0 ? ' ' + Math.round(root.cpuTemp) + '°' : '')
                        + root.trendArrow(root.cpuValue, root.prevCpuDisplay) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("cpu")
                            else root.expanded = !root.expanded
                        }
                    }
                }

                Text {
                    visible: root.showGpu
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.gpuHex + ';">'
                        + root.metricLabel('GPU', 'f625', root.gpuHex) + root.fmt(root.gpuValue) + '%'
                        + (root.showGpuTemp && root.gpuTemp > 0 ? ' ' + Math.round(root.gpuTemp) + '°' : '')
                        + root.trendArrow(root.gpuValue, root.prevGpuDisplay) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("gpu")
                            else root.expanded = !root.expanded
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
                            else root.expanded = !root.expanded
                        }
                    }
                }

                Text {
                    visible: root.showNet
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.netHex + ';">'
                        + root.metricLabel('NET', 'f019', root.netHex) + root.fmtNetSpeed(root.netDownBytes) + '</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("net")
                            else root.expanded = !root.expanded
                        }
                    }
                }

                Text {
                    visible: root.showDisk
                    textFormat: Text.RichText
                    font.pointSize: 10
                    verticalAlignment: Text.AlignVCenter
                    text: '<b><span style="color:' + root.diskHex + ';">'
                        + root.metricLabel('DISK', 'f0a0', root.diskHex) + root.fmt(root.diskValue) + '%</span></b>'
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) root.metricClicked("disk")
                            else root.expanded = !root.expanded
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
                            else root.expanded = !root.expanded
                        }
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
                        else root.expanded = !root.expanded
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
                textFormat: Text.RichText
                text: '<b style="font-size:14pt;">System Monitor</b>'
                color: PlasmaCore.Theme.textColor
            }
            Text {
                visible: root.showCpu
                textFormat: Text.RichText
                text: '<span style="color:' + root.cpuHex + '; font-size:12pt;"><b>CPU:  ' + root.fmt(root.cpuValue) + '%'
                    + (root.showCpuTemp && root.cpuTemp > 0 ? '  ' + Math.round(root.cpuTemp) + '°C' : '') + '</b></span>'
            }
            Text {
                visible: root.showGpu
                textFormat: Text.RichText
                text: '<span style="color:' + root.gpuHex + '; font-size:12pt;"><b>GPU:  ' + root.fmt(root.gpuValue) + '%'
                    + (root.showGpuTemp && root.gpuTemp > 0 ? '  ' + Math.round(root.gpuTemp) + '°C' : '') + '</b></span>'
            }
            Text {
                visible: root.showRam
                textFormat: Text.RichText
                text: '<span style="color:' + root.ramHex + '; font-size:12pt;"><b>RAM:  ' + root.fmtRam() + '</b></span>'
            }
            Text {
                visible: root.showNet
                textFormat: Text.RichText
                text: '<span style="color:' + root.netHex + '; font-size:12pt;"><b>NET:  ' + root.fmtNetSpeed(root.netDownBytes) + '</b></span>'
            }
            Text {
                visible: root.showDisk
                textFormat: Text.RichText
                text: '<span style="color:' + root.diskHex + '; font-size:12pt;"><b>DISK:  ' + root.fmt(root.diskValue) + '%</b></span>'
            }
            Text {
                visible: root.showUptime
                textFormat: Text.RichText
                text: '<span style="color:' + root.uptimeHex + '; font-size:12pt;"><b>UP:  ' + root.fmtUptime(root.uptimeSecs) + '</b></span>'
            }
            Text {
                visible: root.showBat && root.batValue >= 0
                textFormat: Text.RichText
                text: '<span style="color:' + root.batHex + '; font-size:12pt;"><b>BAT:  ' + root.fmt(root.batValue) + '%'
                    + (root.showBatTime ? '  ' + root.fmtBatTime() : '') + '</b></span>'
                    + ((root.showChargingIcon && root.batCharging) ? ' <span style="font-family:\'' + faFont.name + '\'; color:#FFFFFF; font-size:12pt;">&#xf0e7;</span>' : '')
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

    // ── GPU data source ─────────────────────────────────────────
    PlasmaSupport.DataSource {
        id: gpuSource
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
                if (output !== "") {
                    var val = parseFloat(output)
                    if (!isNaN(val)) {
                        prevGpuDisplay = gpuValue
                        gpuValue = val
                    }
                }
            }
        }
    }

    PlasmaSupport.DataSource {
        id: gpuSubscribe
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) {
                disconnectSource(source)
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
        var totalRx = parseFloat(output) || 0
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
        gpuSource.connectSource("sh -c 'busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 sensorData as 1 gpu/gpu1/usage 2>/dev/null | awk \"{print \\$NF}\"'")
        if (showBat || batteryModeEnabled)
            batSource.connectSource("sh -c 'cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo -1); ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0); en=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo 0); ef=$(cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null || echo 0); pw=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0); cl=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo 100); echo \"$cap|$ac|$en|$ef|$pw|$cl\"'")

        if (showCpuTemp || showGpuTemp) {
            tempSource.connectSource("sh -c 'ct=0; gt=0; for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); if [ \"$n\" = \"coretemp\" ]; then v=$(cat $d/temp1_input 2>/dev/null); [ -n \"$v\" ] && ct=$((v/1000)); fi; if [ \"$n\" = \"thinkpad\" ]; then v=$(cat $d/temp2_input 2>/dev/null); [ -n \"$v\" ] && gt=$((v/1000)); fi; done; echo \"$ct $gt\"'")
        }

        if (showNet) {
            netSource.connectSource("sh -c 'awk \"NR>2 && \\$1 !~ /lo:/{gsub(/:/,\\\"\\\",\\$1); sum+=\\$2} END{print sum+0}\" /proc/net/dev'")
        }

        if (showDisk) {
            diskSource.connectSource("sh -c \"df / --output=pcent | tail -1 | tr -d ' %'\"")
        }

        if (showUptime) {
            uptimeSource.connectSource("sh -c \"awk '{print \\$1}' /proc/uptime\"")
        }
    }

    Component.onCompleted: {
        gpuSubscribe.connectSource("busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 subscribe as 1 gpu/gpu1/usage")
        refreshAll()
    }
}
