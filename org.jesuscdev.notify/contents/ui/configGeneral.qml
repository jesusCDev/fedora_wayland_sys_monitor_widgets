import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_historyLimit: limitSpin.value
    property alias cfg_readOnClose: readCheck.checked
    property alias cfg_chipsEnabled: chipsCheck.checked
    property alias cfg_logEnabled: logCheck.checked
    property alias cfg_systemApps: sysField.text
    property alias cfg_groupPatterns: groupField.text

    Kirigami.FormLayout {
        width: root.availableWidth

        SpinBox {
            id: limitSpin
            Kirigami.FormData.label: "History rows:"
            from: 5
            to: 200
        }

        CheckBox {
            id: readCheck
            Kirigami.FormData.label: "Popup:"
            text: "Mark everything read when the popup closes"
        }

        CheckBox {
            id: chipsCheck
            text: "Show copy chips (codes, links, emails)"
        }

        CheckBox {
            id: logCheck
            text: "Log every notification (with body) to ~/.local/state/notify-inline.log"
        }

        TextField {
            id: sysField
            Kirigami.FormData.label: "System section apps (regex):"
            Layout.fillWidth: true
        }

        TextField {
            id: groupField
            Kirigami.FormData.label: "Group rules (comma-separated regex):"
            Layout.fillWidth: true
        }
    }
}
