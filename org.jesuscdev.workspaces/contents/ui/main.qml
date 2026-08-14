import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as PlasmaSupport
import org.kde.taskmanager 0.1 as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation

    // One hue per column = one hue per workflow (1 dev, 2 personal, 3 media)
    readonly property var colColors: ["#90CAF9", "#B39DDB", "#A5D6A7", "#FFCC80"]
    readonly property string currentHex: "#FF8A65"   // bright orange = you are here

    // desktop id (string) -> true when at least one window lives there
    property var occupied: ({})
    // desktop id (string) -> [app names], for the hover tooltip
    property var desktopWins: ({})

    // Panel font scaling: track panel thickness, ~10pt at the default 40px
    property real panelHeight: 0
    readonly property real panelPt: panelHeight > 0
        ? Math.max(10, Math.round(panelHeight * 0.33 * 2) / 2) : 10
    readonly property real cellScale: panelPt / 10

    // Native hover tooltip: one line per occupied workspace with its apps
    toolTipMainText: "Workspace " + beaconLabel().text
    toolTipSubText: {
        var lines = []
        for (var i = 0; i < vdInfo.numberOfDesktops; i++) {
            var apps = desktopWins[vdInfo.desktopIds[i]] || []
            if (i !== currentIndex && apps.length === 0) continue
            var col = i % gridColumns
            var nm = (colNames[col] || ("C" + (col + 1))).trim() + "·" + (Math.floor(i / gridColumns) + 1)
            var shown = apps.slice(0, 4)
            if (apps.length > 4) shown.push("+" + (apps.length - 4) + " more")
            lines.push((i === currentIndex ? "▸ " : "  ") + nm
                + (shown.length ? " — " + shown.join(", ") : ""))
        }
        return lines.join("\n")
    }

    // "grid" = open KWin Grid View (4-finger swipe up); "switch" = jump to clicked desktop
    property string clickAction: Plasmoid.configuration.clickAction
    // Mute occupied-cell colors so only the current desktop pops
    property bool dimOccupied: Plasmoid.configuration.dimOccupied
    // "grid" = 3x3 cells; "minimap" = big current-workspace label + tiny dot map
    property string widgetStyle: Plasmoid.configuration.widgetStyle
    readonly property var colNames: Plasmoid.configuration.columnNames.split(",")

    readonly property int gridColumns: Math.max(1, Math.ceil(vdInfo.numberOfDesktops / Math.max(1, vdInfo.desktopLayoutRows)))

    readonly property int currentIndex: {
        for (var i = 0; i < vdInfo.desktopIds.length; i++)
            if (vdInfo.desktopIds[i] === vdInfo.currentDesktop) return i
        return 0
    }

    function beaconLabel() {
        var col = currentIndex % gridColumns
        var row = Math.floor(currentIndex / gridColumns)
        var name = (colNames[col] || ("C" + (col + 1))).trim()
        return { text: name + "·" + (row + 1), color: colColors[col % colColors.length] }
    }

    function openGridView() {
        switchSource.connectSource("qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Grid View'")
    }

    function cellClicked(index) {
        if (clickAction === "switch")
            switchSource.connectSource("qdbus org.kde.KWin /KWin setCurrentDesktop " + (index + 1))
        else
            openGridView()
    }

    TaskManager.VirtualDesktopInfo {
        id: vdInfo
        // occupancy map goes stale when desktops are added/removed
        onNumberOfDesktopsChanged: root.recompute()
        onDesktopIdsChanged: root.recompute()
    }

    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        onCountChanged: root.recompute()
        onDataChanged: root.recompute()
    }

    function recompute() {
        var occ = {}, wins = {}
        function add(id, name) {
            occ[id] = true
            if (!name) return
            wins[id] = wins[id] || []
            if (wins[id].indexOf(name) < 0) wins[id].push(name)
        }
        for (var i = 0; i < tasksModel.count; i++) {
            var idx = tasksModel.makeModelIndex(i)
            var name = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || ""
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true) {
                for (var d = 0; d < vdInfo.desktopIds.length; d++)
                    add(vdInfo.desktopIds[d], name)
                continue
            }
            var vds = tasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops)
            if (vds)
                for (var j = 0; j < vds.length; j++)
                    add(vds[j], name)
        }
        occupied = occ
        desktopWins = wins
    }

    PlasmaSupport.DataSource {
        id: switchSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            if (data["exit code"] !== undefined)
                disconnectSource(source)
        }
    }

    compactRepresentation: Item {
        onHeightChanged: if (height > 0) root.panelHeight = height
        readonly property real contentWidth: root.widgetStyle === "minimap" ? beacon.implicitWidth : grid.implicitWidth
        Layout.preferredWidth: contentWidth + 14
        Layout.minimumWidth: contentWidth + 14

        MouseArea {  // gaps between cells
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openGridView()
        }

        Row {
            id: beacon
            visible: root.widgetStyle === "minimap"
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pointSize: root.panelPt + 1
                font.bold: true
                color: root.beaconLabel().color
                text: root.beaconLabel().text
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openGridView()
                }
            }

            GridLayout {
                anchors.verticalCenter: parent.verticalCenter
                columns: root.gridColumns
                rowSpacing: 2
                columnSpacing: 2

                Repeater {
                    model: root.widgetStyle === "minimap" ? vdInfo.numberOfDesktops : 0
                    delegate: Rectangle {
                        readonly property string colHex: root.colColors[(index % root.gridColumns) % root.colColors.length]
                        readonly property bool isOccupied: root.occupied[vdInfo.desktopIds[index]] === true
                        readonly property bool isCurrent: index === root.currentIndex

                        width: Math.round(5 * root.cellScale)
                        height: Math.round(5 * root.cellScale)
                        color: isCurrent ? root.currentHex
                             : isOccupied ? Qt.alpha(colHex, root.dimOccupied ? 0.45 : 1.0)
                             : "transparent"
                        border.width: isCurrent ? 0 : 1
                        border.color: Qt.alpha(colHex, isOccupied ? 0.5 : 0.3)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cellClicked(index)
                        }
                    }
                }
            }
        }

        GridLayout {
            id: grid
            visible: root.widgetStyle === "grid"
            anchors.centerIn: parent
            columns: root.gridColumns
            rowSpacing: 1
            columnSpacing: 5

            Repeater {
                model: root.widgetStyle === "grid" ? vdInfo.numberOfDesktops : 0
                delegate: Rectangle {
                    readonly property string colHex: root.colColors[(index % grid.columns) % root.colColors.length]
                    readonly property bool isOccupied: root.occupied[vdInfo.desktopIds[index]] === true
                    readonly property bool isCurrent: vdInfo.currentDesktop === vdInfo.desktopIds[index]

                    width: Math.round(10 * root.cellScale)
                    height: Math.round(7 * root.cellScale)
                    radius: 0
                    color: isCurrent ? root.currentHex
                         : isOccupied ? Qt.alpha(colHex, root.dimOccupied ? 0.35 : 1.0)
                         : "transparent"
                    border.width: isCurrent ? 0 : 1
                    border.color: Qt.alpha(colHex, isOccupied ? (root.dimOccupied ? 0.5 : 1.0) : 0.3)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cellClicked(index)
                    }
                }
            }
        }
    }

    // ponytail: panel never instantiates compact without a fullRepresentation (Plasma 6.7)
    fullRepresentation: Item {
        implicitWidth: 200
        implicitHeight: 60
        Text {
            anchors.centerIn: parent
            color: "#FFFFFF"
            text: "Workspace grid"
        }
    }

    Component.onCompleted: recompute()
}
