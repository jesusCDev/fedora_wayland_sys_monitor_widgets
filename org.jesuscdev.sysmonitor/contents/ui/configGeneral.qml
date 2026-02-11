import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: configPage

    property alias cfg_useDecimals: decimalsCheck.checked
    property alias cfg_ramShowGB: ramGBCheck.checked
    property alias cfg_brightColors: brightCheck.checked
    property alias cfg_warnEnabled: warnCheck.checked
    property alias cfg_showCpu: cpuCheck.checked
    property alias cfg_showGpu: gpuCheck.checked
    property alias cfg_showRam: ramCheck.checked
    property alias cfg_showBat: batCheck.checked
    property alias cfg_showNet: netCheck.checked
    property alias cfg_showCpuTemp: cpuTempCheck.checked
    property alias cfg_showGpuTemp: gpuTempCheck.checked
    property alias cfg_showDisk: diskCheck.checked
    property alias cfg_showUptime: uptimeCheck.checked
    property alias cfg_showBatTime: batTimeCheck.checked
    property alias cfg_showTrendArrows: trendCheck.checked
    property alias cfg_updateIntervalSec: intervalSpin.value
    property alias cfg_batOnRight: batRightCheck.checked
    property alias cfg_showChargingIcon: chargingIconCheck.checked
    property alias cfg_itemSpacing: spacingSpin.value
    property alias cfg_showBatSpacer: batSpacerCheck.checked
    property alias cfg_clickCommand: clickCommandField.text
    property alias cfg_cpuWarnThreshold: cpuWarnSpin.value
    property alias cfg_gpuWarnThreshold: gpuWarnSpin.value
    property alias cfg_ramWarnThreshold: ramWarnSpin.value
    property alias cfg_batWarnThreshold: batWarnSpin.value
    property alias cfg_cpuColor: cpuColorField.text
    property alias cfg_gpuColor: gpuColorField.text
    property alias cfg_ramColor: ramColorField.text
    property alias cfg_batColor: batColorField.text
    property alias cfg_netColor: netColorField.text
    property alias cfg_diskColor: diskColorField.text
    property alias cfg_uptimeColor: uptimeColorField.text
    property alias cfg_warnColor: warnColorField.text

    Kirigami.FormLayout {
        width: configPage.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Visible Items"
        }

        CheckBox {
            id: cpuCheck
            Kirigami.FormData.label: "CPU:"
            text: "Show CPU usage"
        }

        CheckBox {
            id: cpuTempCheck
            Kirigami.FormData.label: "CPU temp:"
            text: "Show CPU temperature"
        }

        CheckBox {
            id: gpuCheck
            Kirigami.FormData.label: "GPU:"
            text: "Show GPU usage"
        }

        CheckBox {
            id: gpuTempCheck
            Kirigami.FormData.label: "GPU temp:"
            text: "Show GPU temperature"
        }

        CheckBox {
            id: ramCheck
            Kirigami.FormData.label: "RAM:"
            text: "Show RAM usage"
        }

        CheckBox {
            id: netCheck
            Kirigami.FormData.label: "Network:"
            text: "Show network download speed"
        }

        CheckBox {
            id: diskCheck
            Kirigami.FormData.label: "Disk:"
            text: "Show disk usage"
        }

        CheckBox {
            id: uptimeCheck
            Kirigami.FormData.label: "Uptime:"
            text: "Show system uptime"
        }

        CheckBox {
            id: batCheck
            Kirigami.FormData.label: "Battery:"
            text: "Show battery level"
        }

        CheckBox {
            id: batTimeCheck
            Kirigami.FormData.label: "Battery time:"
            text: "Show estimated time remaining"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Display"
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
            id: warnCheck
            Kirigami.FormData.label: "Warnings:"
            text: "Color change at warning thresholds"
        }

        CheckBox {
            id: trendCheck
            Kirigami.FormData.label: "Trend arrows:"
            text: "Show arrows when values rise or fall"
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
            text: "Show | divider between battery and other items"
        }

        SpinBox {
            id: spacingSpin
            Kirigami.FormData.label: "Item spacing:"
            from: 1
            to: 10
            stepSize: 1
        }

        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Update interval (seconds):"
            from: 1
            to: 60
            stepSize: 1
        }

        TextField {
            id: clickCommandField
            Kirigami.FormData.label: "Click command:"
            placeholderText: "wezterm -e htop"
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Warning Thresholds"
        }

        SpinBox {
            id: cpuWarnSpin
            Kirigami.FormData.label: "CPU warning (%):"
            from: 0
            to: 100
            stepSize: 5
        }

        SpinBox {
            id: gpuWarnSpin
            Kirigami.FormData.label: "GPU warning (%):"
            from: 0
            to: 100
            stepSize: 5
        }

        SpinBox {
            id: ramWarnSpin
            Kirigami.FormData.label: "RAM warning (%):"
            from: 0
            to: 100
            stepSize: 5
        }

        SpinBox {
            id: batWarnSpin
            Kirigami.FormData.label: "Battery warning (%):"
            from: 0
            to: 100
            stepSize: 5
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Custom Colors (leave empty for default)"
        }

        TextField {
            id: cpuColorField
            Kirigami.FormData.label: "CPU color:"
            placeholderText: "#80D8FF"
        }

        TextField {
            id: gpuColorField
            Kirigami.FormData.label: "GPU color:"
            placeholderText: "#69F0AE"
        }

        TextField {
            id: ramColorField
            Kirigami.FormData.label: "RAM color:"
            placeholderText: "#EA80FC"
        }

        TextField {
            id: netColorField
            Kirigami.FormData.label: "Network color:"
            placeholderText: "#80DEEA"
        }

        TextField {
            id: diskColorField
            Kirigami.FormData.label: "Disk color:"
            placeholderText: "#FFB74D"
        }

        TextField {
            id: uptimeColorField
            Kirigami.FormData.label: "Uptime color:"
            placeholderText: "#ECEFF1"
        }

        TextField {
            id: batColorField
            Kirigami.FormData.label: "Battery color:"
            placeholderText: "#FFEE58"
        }

        TextField {
            id: warnColorField
            Kirigami.FormData.label: "Warning color:"
            placeholderText: "#FF5252"
        }
    }
}
