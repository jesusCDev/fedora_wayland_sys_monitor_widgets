import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.workspace.calendar 2.0 as PlasmaCalendar

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation

    property date now: new Date()

    // Pastel palette, one hue per component
    readonly property string weekdayHex: "#B39DDB"   // pastel lavender
    readonly property string dateHex: "#90CAF9"      // pastel blue
    readonly property string timeHex: "#FFFFFF"      // white
    readonly property string meridiemHex: "#8A8A8A"  // dim gray
    readonly property string sepHex: "#8A8A8A"

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function clockHtml() {
        var wd = Qt.formatDateTime(now, "ddd")
        var md = Qt.formatDateTime(now, "MMM d")
        var t = Qt.formatDateTime(now, "h:mm")
        var ap = Qt.formatDateTime(now, "AP")
        return '<b>'
            + '<span style="color:' + weekdayHex + ';">' + wd + '</span> '
            + '<span style="color:' + dateHex + ';">' + md + '</span>'
            + '<span style="color:' + sepHex + ';"> &#183; </span>'
            + '<span style="color:' + timeHex + ';">' + t + '</span>'
            + ' <span style="color:' + meridiemHex + ';">' + ap + '</span>'
            + '</b>'
    }

    compactRepresentation: Item {
        Layout.preferredWidth: clockText.implicitWidth + 12
        Layout.minimumWidth: clockText.implicitWidth + 12

        Text {
            id: clockText
            anchors.centerIn: parent
            textFormat: Text.RichText
            font.pointSize: 10
            verticalAlignment: Text.AlignVCenter
            text: root.clockHtml()
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Item {
        implicitWidth: 340
        implicitHeight: 360
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        PlasmaCalendar.MonthView {
            anchors.fill: parent
            anchors.margins: 10
            today: root.now
        }
    }
}
