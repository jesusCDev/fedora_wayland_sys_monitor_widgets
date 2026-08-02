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
        Layout.preferredWidth: grid.implicitWidth + 14
        Layout.minimumWidth: grid.implicitWidth + 14

        GridLayout {
            id: grid
            anchors.centerIn: parent
            columns: Math.max(1, Math.ceil(vdInfo.numberOfDesktops / Math.max(1, vdInfo.desktopLayoutRows)))
            rowSpacing: 1
            columnSpacing: 5

            Repeater {
                model: vdInfo.numberOfDesktops
                delegate: Rectangle {
                    readonly property string colHex: root.colColors[(index % grid.columns) % root.colColors.length]
                    readonly property bool isOccupied: root.occupied[vdInfo.desktopIds[index]] === true
                    readonly property bool isCurrent: vdInfo.currentDesktop === vdInfo.desktopIds[index]

                    width: 15
                    height: 7
                    radius: 0
                    color: isCurrent ? root.currentHex : (isOccupied ? colHex : "transparent")
                    border.width: isCurrent ? 0 : 1
                    border.color: Qt.alpha(colHex, isOccupied ? 1.0 : 0.4)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switchSource.connectSource("qdbus org.kde.KWin /KWin setCurrentDesktop " + (index + 1))
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
