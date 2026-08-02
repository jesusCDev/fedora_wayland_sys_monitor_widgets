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
    readonly property string currentHex: "#D97757"   // Claude orange ring = you are here

    // desktop id (string) -> true when at least one window lives there
    property var occupied: ({})

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
        var occ = {}
        for (var i = 0; i < tasksModel.count; i++) {
            var idx = tasksModel.makeModelIndex(i)
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops) === true) {
                for (var d = 0; d < vdInfo.desktopIds.length; d++)
                    occ[vdInfo.desktopIds[d]] = true
                continue
            }
            var vds = tasksModel.data(idx, TaskManager.AbstractTasksModel.VirtualDesktops)
            if (vds)
                for (var j = 0; j < vds.length; j++)
                    occ[vds[j]] = true
        }
        occupied = occ
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
                font.pointSize: 11
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

                        width: 5
                        height: 5
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

                    width: 15
                    height: 7
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
