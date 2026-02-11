import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_useDecimals: decimalsCheck.checked
    property alias cfg_ramShowGB: ramGBCheck.checked
    property alias cfg_brightColors: brightCheck.checked
    property alias cfg_showTrendArrows: trendCheck.checked
    property alias cfg_useIcons: iconsCheck.checked
    property alias cfg_batOnRight: batRightCheck.checked
    property alias cfg_showChargingIcon: chargingIconCheck.checked
    property alias cfg_showBatSpacer: batSpacerCheck.checked
    property alias cfg_itemSpacing: spacingSpin.value

    Kirigami.FormLayout {
        width: root.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Format"
        }

        CheckBox {
            id: decimalsCheck
            Kirigami.FormData.label: "Decimals:"
            text: "Show decimal values (e.g. 1.2% instead of 1%)"
        }

        CheckBox {
            id: ramGBCheck
            Kirigami.FormData.label: "RAM display:"
            text: "Show RAM in GB instead of percentage"
        }

        CheckBox {
            id: brightCheck
            Kirigami.FormData.label: "Colors:"
            text: "Use bright/vivid colors (for dark panels)"
        }

        CheckBox {
            id: trendCheck
            Kirigami.FormData.label: "Trend arrows:"
            text: "Show arrows when values rise or fall"
        }

        CheckBox {
            id: iconsCheck
            Kirigami.FormData.label: "Icons:"
            text: "Use icons instead of text labels"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Layout"
        }

        CheckBox {
            id: batRightCheck
            Kirigami.FormData.label: "Battery position:"
            text: "Move battery to right side"
        }

        CheckBox {
            id: chargingIconCheck
            Kirigami.FormData.label: "Charging icon:"
            text: "Show lightning bolt when charging"
        }

        CheckBox {
            id: batSpacerCheck
            Kirigami.FormData.label: "Battery separator:"
            text: "Show divider between battery and other items"
        }

        SpinBox {
            id: spacingSpin
            Kirigami.FormData.label: "Item spacing:"
            from: 1
            to: 10
            stepSize: 1
        }
    }
}
