import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs as QtDialogs
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_cpuColor: cpuColorField.text
    property alias cfg_gpuColor: gpuColorField.text
    property alias cfg_ramColor: ramColorField.text
    property alias cfg_netColor: netColorField.text
    property alias cfg_diskColor: diskColorField.text
    property alias cfg_uptimeColor: uptimeColorField.text
    property alias cfg_batColor: batColorField.text
    property alias cfg_warnColor: warnColorField.text

    Kirigami.FormLayout {
        width: root.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Custom Colors (leave empty for default)"
        }

        RowLayout {
            Kirigami.FormData.label: "CPU color:"
            TextField {
                id: cpuColorField
                placeholderText: "#80D8FF"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: cpuColorField.text || cpuColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cpuColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: cpuColorDialog
                selectedColor: cpuColorField.text || cpuColorField.placeholderText
                onAccepted: cpuColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "GPU color:"
            TextField {
                id: gpuColorField
                placeholderText: "#69F0AE"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: gpuColorField.text || gpuColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: gpuColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: gpuColorDialog
                selectedColor: gpuColorField.text || gpuColorField.placeholderText
                onAccepted: gpuColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "RAM color:"
            TextField {
                id: ramColorField
                placeholderText: "#EA80FC"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: ramColorField.text || ramColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ramColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: ramColorDialog
                selectedColor: ramColorField.text || ramColorField.placeholderText
                onAccepted: ramColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Network color:"
            TextField {
                id: netColorField
                placeholderText: "#80DEEA"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: netColorField.text || netColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: netColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: netColorDialog
                selectedColor: netColorField.text || netColorField.placeholderText
                onAccepted: netColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Disk color:"
            TextField {
                id: diskColorField
                placeholderText: "#FFB74D"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: diskColorField.text || diskColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: diskColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: diskColorDialog
                selectedColor: diskColorField.text || diskColorField.placeholderText
                onAccepted: diskColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Uptime color:"
            TextField {
                id: uptimeColorField
                placeholderText: "#ECEFF1"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: uptimeColorField.text || uptimeColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: uptimeColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: uptimeColorDialog
                selectedColor: uptimeColorField.text || uptimeColorField.placeholderText
                onAccepted: uptimeColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Battery color:"
            TextField {
                id: batColorField
                placeholderText: "#FFEE58"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: batColorField.text || batColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: batColorDialog
                selectedColor: batColorField.text || batColorField.placeholderText
                onAccepted: batColorField.text = selectedColor
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Warning color:"
            TextField {
                id: warnColorField
                placeholderText: "#FF5252"
                Layout.fillWidth: true
            }
            Rectangle {
                width: 24; height: 24
                color: warnColorField.text || warnColorField.placeholderText
                border.color: "#888"; border.width: 1; radius: 3
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: warnColorDialog.open()
                }
            }
            QtDialogs.ColorDialog {
                id: warnColorDialog
                selectedColor: warnColorField.text || warnColorField.placeholderText
                onAccepted: warnColorField.text = selectedColor
            }
        }
    }
}
