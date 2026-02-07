import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: configPage

    property alias cfg_useDecimals: decimalsCheck.checked
    property alias cfg_ramShowGB: ramGBCheck.checked
    property alias cfg_brightColors: brightCheck.checked
    property alias cfg_warnEnabled: warnCheck.checked
    property alias cfg_showCpu: cpuCheck.checked
    property alias cfg_showGpu: gpuCheck.checked
    property alias cfg_showRam: ramCheck.checked
    property alias cfg_showBat: batCheck.checked
    property alias cfg_updateIntervalSec: intervalSpin.value
    property alias cfg_batOnRight: batRightCheck.checked
    property alias cfg_showChargingIcon: chargingIconCheck.checked
    property alias cfg_cpuColor: cpuColorField.text
    property alias cfg_gpuColor: gpuColorField.text
    property alias cfg_ramColor: ramColorField.text
    property alias cfg_batColor: batColorField.text
    property alias cfg_warnColor: warnColorField.text

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
        id: gpuCheck
        Kirigami.FormData.label: "GPU:"
        text: "Show GPU usage"
    }

    CheckBox {
        id: ramCheck
        Kirigami.FormData.label: "RAM:"
        text: "Show RAM usage"
    }

    CheckBox {
        id: batCheck
        Kirigami.FormData.label: "Battery:"
        text: "Show battery level"
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
        text: "Red at 90% usage (CPU/GPU/RAM) and 15% battery"
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

    SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: "Update interval (seconds):"
        from: 1
        to: 60
        stepSize: 1
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
