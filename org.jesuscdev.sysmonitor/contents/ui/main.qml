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

    // Current values (raw decimals)
    property real cpuValue: 0.0
    property real gpuValue: 0.0
    property real ramValue: 0.0
    property real ramUsedGB: 0.0
    property real batValue: -1.0    // -1 = no battery detected
    property bool batCharging: false

    // CPU delta tracking
    property real prevCpuIdle: 0
    property real prevCpuTotal: 0
    property bool cpuFirstRun: true

    // Settings (persisted via Plasmoid.configuration)
    property bool useDecimals: Plasmoid.configuration.useDecimals
    property bool ramShowGB: Plasmoid.configuration.ramShowGB
    property bool brightColors: Plasmoid.configuration.brightColors
    property bool warnEnabled: Plasmoid.configuration.warnEnabled
    property bool showCpu: Plasmoid.configuration.showCpu
    property bool showGpu: Plasmoid.configuration.showGpu
    property bool showRam: Plasmoid.configuration.showRam
    property bool showBat: Plasmoid.configuration.showBat
    property int updateIntervalSec: Plasmoid.configuration.updateIntervalSec
    property bool batOnRight: Plasmoid.configuration.batOnRight
    property bool showChargingIcon: Plasmoid.configuration.showChargingIcon
    property int itemSpacing: Plasmoid.configuration.itemSpacing
    property bool showBatSpacer: Plasmoid.configuration.showBatSpacer

    // Custom color overrides (empty string = use default)
    property string cpuColorOverride: Plasmoid.configuration.cpuColor
    property string gpuColorOverride: Plasmoid.configuration.gpuColor
    property string ramColorOverride: Plasmoid.configuration.ramColor
    property string batColorOverride: Plasmoid.configuration.batColor
    property string warnColorOverride: Plasmoid.configuration.warnColor

    // ── Color definitions ───────────────────────────────────────
    readonly property string cpuHexNormal: "#42A5F5"    // blue
    readonly property string gpuHexNormal: "#66BB6A"    // green
    readonly property string ramHexNormal: "#AB47BC"    // purple
    readonly property string batHexNormal: "#FDD835"    // yellow

    readonly property string cpuHexBright: "#80D8FF"
    readonly property string gpuHexBright: "#69F0AE"
    readonly property string ramHexBright: "#EA80FC"
    readonly property string batHexBright: "#FFEE58"

    readonly property string warnHexNormal: "#EF5350"
    readonly property string warnHexBright: "#FF5252"
    property string warnHex: warnColorOverride !== ""
        ? warnColorOverride : (brightColors ? warnHexBright : warnHexNormal)

    // Resolved colors (accounting for warnings, then overrides, then bright/normal)
    property string cpuHex: (warnEnabled && cpuValue >= 90)
        ? warnHex : (cpuColorOverride !== "" ? cpuColorOverride : (brightColors ? cpuHexBright : cpuHexNormal))
    property string gpuHex: (warnEnabled && gpuValue >= 90)
        ? warnHex : (gpuColorOverride !== "" ? gpuColorOverride : (brightColors ? gpuHexBright : gpuHexNormal))
    property string ramHex: (warnEnabled && ramValue >= 90)
        ? warnHex : (ramColorOverride !== "" ? ramColorOverride : (brightColors ? ramHexBright : ramHexNormal))
    property string batHex: (warnEnabled && batValue >= 0 && batValue <= 15)
        ? warnHex : (batColorOverride !== "" ? batColorOverride : (brightColors ? batHexBright : batHexNormal))

    // Format helpers
    function fmt(val) {
        return useDecimals ? val.toFixed(1) : Math.round(val).toString()
    }

    function fmtRam() {
        if (ramShowGB) return ramUsedGB.toFixed(1) + 'GB'
        return fmt(ramValue) + '%'
    }

    // Build colored HTML for the panel
    function panelHtml() {
        var sep = ''
        for (var i = 0; i < itemSpacing; i++) sep += '&nbsp;'

        var batSep = sep
        if (showBatSpacer) {
            var pad = ''
            for (var j = 0; j < 3; j++) pad += '&nbsp;'
            batSep = pad + '<span style="color:#FFFFFF;">|</span>' + pad
        }

        // System metrics group
        var sys = []
        if (showCpu)
            sys.push('<b><span style="color:' + cpuHex + ';">CPU ' + fmt(cpuValue) + '%</span></b>')
        if (showGpu)
            sys.push('<b><span style="color:' + gpuHex + ';">GPU ' + fmt(gpuValue) + '%</span></b>')
        if (showRam)
            sys.push('<b><span style="color:' + ramHex + ';">RAM ' + fmtRam() + '</span></b>')

        // Battery
        var bat = ''
        if (showBat && batValue >= 0) {
            var bolt = (showChargingIcon && batCharging) ? ' <span style="color:#FFFFFF;">&#x21AF;</span>' : ''
            bat = '<b><span style="color:' + batHex + ';">BAT ' + fmt(batValue) + '%</span></b>' + bolt
        }

        var sysStr = sys.join(sep)

        if (bat === '') return sysStr
        if (sysStr === '') return bat

        if (batOnRight)
            return sysStr + batSep + bat
        else
            return bat + batSep + sysStr
    }

    // ── Panel view ──────────────────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot
        Layout.preferredWidth: panelText.implicitWidth + 24
        Layout.minimumWidth: panelText.implicitWidth + 24

        Text {
            id: panelText
            anchors.centerIn: parent
            textFormat: Text.RichText
            text: root.panelHtml()
            font.pointSize: 10
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
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
                text: '<span style="color:' + root.cpuHex + '; font-size:12pt;"><b>CPU:  ' + root.fmt(root.cpuValue) + '%</b></span>'
            }
            Text {
                visible: root.showGpu
                textFormat: Text.RichText
                text: '<span style="color:' + root.gpuHex + '; font-size:12pt;"><b>GPU:  ' + root.fmt(root.gpuValue) + '%</b></span>'
            }
            Text {
                visible: root.showRam
                textFormat: Text.RichText
                text: '<span style="color:' + root.ramHex + '; font-size:12pt;"><b>RAM:  ' + root.fmtRam() + '</b></span>'
            }
            Text {
                visible: root.showBat && root.batValue >= 0
                textFormat: Text.RichText
                text: '<span style="color:' + root.batHex + '; font-size:12pt;"><b>BAT:  ' + root.fmt(root.batValue) + '%</b></span>' + ((root.showChargingIcon && root.batCharging) ? ' <span style="color:#FFFFFF; font-size:12pt;"><b>&#x21AF;</b></span>' : '')
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
                if (capStr !== "" && capStr !== "-1") {
                    var val = parseFloat(capStr)
                    if (!isNaN(val)) {
                        batValue = val
                    }
                } else {
                    batValue = -1
                }
                batCharging = (acStr === "1")
            }
        }
    }

    // ── Timer (interval driven by config) ───────────────────────
    Timer {
        id: updateTimer
        interval: root.updateIntervalSec * 1000
        running: true
        repeat: true
        onTriggered: refreshAll()
    }

    function refreshAll() {
        cpuSource.connectSource("head -1 /proc/stat")
        ramSource.connectSource("head -3 /proc/meminfo")
        gpuSource.connectSource("sh -c 'busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 sensorData as 1 gpu/gpu1/usage 2>/dev/null | awk \"{print \\$NF}\"'")
        batSource.connectSource("sh -c 'cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo -1); ac=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0); echo \"$cap|$ac\"'")
    }

    Component.onCompleted: {
        gpuSubscribe.connectSource("busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 subscribe as 1 gpu/gpu1/usage")
        refreshAll()
    }
}
