import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property string cfg_clickAction
    property string cfg_widgetStyle
    property alias cfg_dimOccupied: dimCheck.checked
    property alias cfg_columnNames: namesField.text

    Kirigami.FormLayout {
        width: root.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Appearance"
        }

        RadioButton {
            Kirigami.FormData.label: "Style:"
            text: "3×3 grid"
            checked: root.cfg_widgetStyle === "grid"
            onToggled: if (checked) root.cfg_widgetStyle = "grid"
        }

        RadioButton {
            text: "Beacon + minimap (big current-workspace label, tiny dot map)"
            checked: root.cfg_widgetStyle === "minimap"
            onToggled: if (checked) root.cfg_widgetStyle = "minimap"
        }

        TextField {
            id: namesField
            Kirigami.FormData.label: "Column names:"
            placeholderText: "DEV,PER,MED"
        }

        CheckBox {
            id: dimCheck
            Kirigami.FormData.label: "Colors:"
            text: "Dim occupied workspaces (only current one pops)"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Click behavior"
        }

        RadioButton {
            Kirigami.FormData.label: "On click:"
            text: "Open desktop grid (same as 4-finger swipe up)"
            checked: root.cfg_clickAction === "grid"
            onToggled: if (checked) root.cfg_clickAction = "grid"
        }

        RadioButton {
            text: "Switch to the clicked workspace"
            checked: root.cfg_clickAction === "switch"
            onToggled: if (checked) root.cfg_clickAction = "switch"
        }
    }
}
