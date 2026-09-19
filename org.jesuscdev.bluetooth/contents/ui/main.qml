import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as PlasmaSupport

PlasmoidItem {
    id: root
    preferredRepresentation: Plasmoid.compactRepresentation

    // ── Config ────────────────────────────────────────────────
    property int pollIntervalSec: Plasmoid.configuration.pollIntervalSec
    property int nameMaxChars: Plasmoid.configuration.nameMaxChars
    property int scanDurationSec: Plasmoid.configuration.scanDurationSec

    // ── Colors ────────────────────────────────────────────────
    readonly property string colorOff: "#8A8A8A"
    readonly property string colorOn: "#FFFFFF"
    readonly property string colorConnected: "#4FC3F7"
    readonly property string colorDim: "#B0B0B0"

    // ── Panel scaling (same recipe as sysmonitor) ─────────────
    property real panelHeight: 0
    readonly property real panelPt: panelHeight > 0
        ? Math.max(10, Math.round(panelHeight * 0.33 * 2) / 2) : 10

    // ── State ─────────────────────────────────────────────────
    property bool adapterPowered: false
    property bool scanning: false
    property bool polling: false
    // ponytail: one action in flight via busyMac, no queue — add one if
    // multi-device pairing sessions ever hit the gate
    property string busyMac: ""
    property bool hoverBt: false
    property Item panelAnchor: null
    property var pairedDevices: []   // [{mac, name, connected, battery}]
    property var foundDevices: []    // [{mac, name}] — populated only right after a scan
    readonly property var connectedDevices: pairedDevices.filter(function(d) { return d.connected })

    // Suppress the built-in tooltip; we anchor our own styled one
    toolTipMainText: ""
    toolTipSubText: ""

    // ── Panel HTML ────────────────────────────────────────────
    // The bluetooth glyph lives in the FA-brands range, which fa-solid-900
    // lacks; Hack Nerd Font (system-wide here) carries it at f294.
    readonly property bool hasGlyphFont: Qt.fontFamilies().indexOf("Hack Nerd Font") >= 0

    function btGlyph(color) {
        if (hasGlyphFont)
            // 1.5×: the rune's ink is ~0.7em, so it needs more than the PNG icons' scale to match them
            return '<span style="font-family:\'Hack Nerd Font\'; font-size:' + Math.round(panelPt * 1.5) + 'pt; color:' + color + ';">&#xf294;</span>'
        return '<b><span style="color:' + color + ';">BT</span></b>'
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function shortenName(name) {
        // ponytail: naive truncate, no smart abbreviation
        return name.length > nameMaxChars ? name.substring(0, nameMaxChars) : name
    }

    readonly property string btColor: !adapterPowered ? colorOff : (connectedDevices.length ? colorConnected : colorOn)

    function btLabelHtml() {
        if (!adapterPowered || !connectedDevices.length) return ""
        var d = connectedDevices[0]
        var extra = connectedDevices.length > 1 ? " +" + (connectedDevices.length - 1) : ""
        return '<span style="color:' + btColor + ';">' + escapeHtml(shortenName(d.name))
            + (d.battery >= 0 ? " " + d.battery + "%" : "") + extra + '</span>'
    }

    // ── Poll: one aggregated command per tick ─────────────────
    // MACs only ever appear in commands (device names can hold apostrophes);
    // no single quotes inside — the whole thing is wrapped in sh -c '...'
    readonly property string pollCmd: "sh -c '" +
        "echo @@ADAPTER; bluetoothctl show; " +
        "echo @@PAIRED; bluetoothctl devices Paired; " +
        "echo @@CONNECTED; bluetoothctl devices Connected; " +
        "bluetoothctl devices Connected | while read _ m _; do echo @@INFO $m; bluetoothctl info $m; done'"

    function refreshPoll() {
        if (polling) return
        polling = true
        pollSource.connectSource(pollCmd)
    }

    function parsePoll(text) {
        var lines = text.split("\n")
        var section = "", infoMac = ""
        var pairedMap = {}, connectedSet = {}, infoByMac = {}
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("@@ADAPTER") === 0) { section = "adapter"; continue }
            if (ln.indexOf("@@PAIRED") === 0) { section = "paired"; continue }
            if (ln.indexOf("@@CONNECTED") === 0) { section = "connected"; continue }
            if (ln.indexOf("@@INFO ") === 0) { section = "info"; infoMac = ln.substring(7).trim(); infoByMac[infoMac] = {}; continue }

            if (section === "adapter") {
                if (ln.indexOf("Powered:") >= 0) adapterPowered = ln.indexOf("yes") >= 0
            } else if (section === "paired") {
                var m = ln.match(/^Device (\S+) (.+)$/)
                if (m) pairedMap[m[1]] = m[2]
            } else if (section === "connected") {
                var m2 = ln.match(/^Device (\S+) /)
                if (m2) connectedSet[m2[1]] = true
            } else if (section === "info" && infoMac) {
                if (ln.indexOf("Battery Percentage:") >= 0) {
                    var bm = ln.match(/\((\d+)\)/)
                    if (bm) infoByMac[infoMac].battery = parseInt(bm[1])
                }
            }
        }
        var list = []
        for (var mac in pairedMap) {
            var info = infoByMac[mac] || {}
            list.push({
                mac: mac,
                name: pairedMap[mac],
                connected: !!connectedSet[mac],
                battery: info.battery !== undefined ? info.battery : -1
            })
        }
        list.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        pairedDevices = list
    }

    PlasmaSupport.DataSource {
        id: pollSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            buffers[source] = (buffers[source] || "") + (data["stdout"] || "")
            if (data["exit code"] !== undefined) {
                var out = buffers[source] || ""
                delete buffers[source]
                disconnectSource(source)
                root.polling = false
                root.parsePoll(out)
            }
        }
    }

    Timer {
        interval: root.pollIntervalSec * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshPoll()
    }

    // ── Scan: discovery blocks for its own duration ───────────
    function startScan() {
        if (scanning) return
        scanning = true
        foundDevices = []
        scanSource.connectSource("bluetoothctl --timeout " + scanDurationSec + " scan on")
    }

    PlasmaSupport.DataSource {
        id: scanSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) {
                disconnectSource(source)
                root.scanning = false
                root.refreshFound()
            }
        }
    }

    function refreshFound() {
        listSource.connectSource("sh -c 'bluetoothctl devices; echo @@PAIRED; bluetoothctl devices Paired'")
    }

    function parseFound(text) {
        var lines = text.split("\n")
        var section = "all", all = {}, pairedMacs = {}
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i]
            if (ln.indexOf("@@PAIRED") === 0) { section = "paired"; continue }
            var m = ln.match(/^Device (\S+) (.+)$/)
            if (!m) continue
            if (section === "paired") pairedMacs[m[1]] = true
            else all[m[1]] = m[2]
        }
        var found = []
        for (var mac in all) if (!pairedMacs[mac]) found.push({mac: mac, name: all[mac]})
        found.sort(function(a, b) { return a.name.localeCompare(b.name) })
        foundDevices = found
    }

    PlasmaSupport.DataSource {
        id: listSource
        engine: "executable"
        connectedSources: []
        property var buffers: ({})
        onNewData: function(source, data) {
            buffers[source] = (buffers[source] || "") + (data["stdout"] || "")
            if (data["exit code"] !== undefined) {
                var out = buffers[source] || ""
                delete buffers[source]
                disconnectSource(source)
                root.parseFound(out)
            }
        }
    }

    // ── Row actions: connect / disconnect / pair ──────────────
    function rowClicked(dev, isFound) {
        if (busyMac !== "") return
        busyMac = dev.mac
        var cmd = isFound
            ? "bluetoothctl pair " + dev.mac + " && bluetoothctl trust " + dev.mac + " && bluetoothctl connect " + dev.mac
            : (dev.connected ? "bluetoothctl disconnect " + dev.mac : "bluetoothctl connect " + dev.mac)
        actionSource.connectSource("sh -c '" + cmd + "'")
    }

    PlasmaSupport.DataSource {
        id: actionSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) {
                disconnectSource(source)
                root.busyMac = ""
                root.refreshPoll()
                if (root.foundDevices.length) root.refreshFound()
            }
        }
    }

    // ── Fire-and-forget launcher ──────────────────────────────
    function launchApp(cmd) {
        if (cmd !== "")
            launchSource.connectSource("sh -c '" + cmd + " &'")
    }

    PlasmaSupport.DataSource {
        id: launchSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined) disconnectSource(source)
        }
    }

    onExpandedChanged: {
        if (expanded) refreshPoll()
        else foundDevices = []
    }

    // ── Hover tooltip ─────────────────────────────────────────
    // Single fixed anchor, so no rearm blink needed (that exists in
    // sysmonitor only because segments slide under one shared Dialog)
    PlasmaCore.Dialog {
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.ToolTip
        location: Plasmoid.location
        visualParent: root.panelAnchor
        visible: root.hoverBt && root.panelAnchor !== null && !root.expanded

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
                        color: root.adapterPowered ? root.colorOn : root.colorOff
                        text: !root.adapterPowered ? "Bluetooth off"
                            : (root.scanning ? "Bluetooth — scanning…" : "Bluetooth on")
                    }
                    Repeater {
                        model: root.pairedDevices
                        Text {
                            // PlainText: device names are attacker-controlled,
                            // AutoText would render markup smuggled into them
                            textFormat: Text.PlainText
                            font.pointSize: 10
                            color: modelData.connected ? root.colorConnected : root.colorDim
                            text: (modelData.connected ? "● " : "○ ") + modelData.name
                                + (modelData.connected && modelData.battery >= 0 ? "  " + modelData.battery + "%" : "")
                        }
                    }
                    Text {
                        visible: root.pairedDevices.length === 0
                        color: root.colorOff
                        font.pointSize: 10
                        text: "No paired devices"
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

        // Glyph and label as separate items so each centres on the panel;
        // one rich-text line would hang the bigger glyph off the label's baseline.
        Row {
            id: panelRow
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                text: root.btGlyph(root.btColor)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                textFormat: Text.RichText
                font.pointSize: root.panelPt
                text: root.btLabelHtml()
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
                if (Plasmoid.location === PlasmaCore.Types.BottomEdge ? f > 0.4 : f < 0.6) root.hoverBt = true
            }
            onExited: root.hoverBt = false
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) root.expanded = !root.expanded
                else root.launchApp("plasma-open-settings kcm_bluetooth")
            }
        }
    }

    // ── Popup view ────────────────────────────────────────────
    fullRepresentation: Item {
        implicitWidth: 280
        implicitHeight: Math.min(popupCol.implicitHeight + 40, 500)
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
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: popupCol.implicitWidth
            contentHeight: popupCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: popupCol
                width: 240
                spacing: 8

                Text {
                    font.bold: true
                    font.pointSize: 11
                    color: root.adapterPowered ? root.colorOn : root.colorOff
                    text: root.adapterPowered ? "Bluetooth on" : "Bluetooth off"
                }

                Text {
                    color: root.colorDim
                    font.pointSize: 9
                    text: "PAIRED"
                }

                Repeater {
                    model: root.pairedDevices
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: pairedRow.implicitHeight + 6

                        RowLayout {
                            id: pairedRow
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                color: modelData.connected ? root.colorConnected : root.colorDim
                                text: modelData.connected ? "●" : "○"
                            }
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                color: root.colorOn
                                elide: Text.ElideRight
                                text: modelData.name
                            }
                            Text {
                                visible: modelData.connected && modelData.battery >= 0
                                color: root.colorDim
                                text: modelData.battery + "%"
                            }
                            Text {
                                visible: root.busyMac === modelData.mac
                                color: root.colorDim
                                text: "…"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.busyMac === ""
                            onClicked: root.rowClicked(modelData, false)
                        }
                    }
                }

                Text {
                    visible: root.pairedDevices.length === 0
                    color: root.colorOff
                    font.pointSize: 9
                    text: "No paired devices"
                }

                Button {
                    Layout.topMargin: 4
                    text: root.scanning ? "Scanning…" : "Scan"
                    enabled: !root.scanning && root.adapterPowered
                    onClicked: root.startScan()
                }

                Text {
                    visible: root.foundDevices.length > 0
                    Layout.topMargin: 4
                    color: root.colorDim
                    font.pointSize: 9
                    text: "FOUND"
                }

                Repeater {
                    model: root.foundDevices
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: foundRow.implicitHeight + 6

                        RowLayout {
                            id: foundRow
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                color: root.colorOn
                                elide: Text.ElideRight
                                text: modelData.name
                            }
                            Text {
                                visible: root.busyMac === modelData.mac
                                color: root.colorDim
                                text: "pairing…"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.busyMac === ""
                            onClicked: root.rowClicked(modelData, true)
                        }
                    }
                }
            }
        }
    }
}
