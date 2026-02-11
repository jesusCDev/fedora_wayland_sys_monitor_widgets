import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_warnEnabled: warnCheck.checked
    property alias cfg_cpuWarnThreshold: cpuWarnSpin.value
    property alias cfg_gpuWarnThreshold: gpuWarnSpin.value
    property alias cfg_ramWarnThreshold: ramWarnSpin.value
    property alias cfg_batWarnThreshold: batWarnSpin.value
    property alias cfg_updateIntervalSec: intervalSpin.value
    property alias cfg_batteryModeEnabled: batModeCheck.checked
    property alias cfg_batteryModeInterval: batModeIntervalSpin.value
    property alias cfg_clickCommand: clickCommandField.text

    Kirigami.FormLayout {
        width: root.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Warning Thresholds"
        }

        CheckBox {
            id: warnCheck
            Kirigami.FormData.label: "Warnings:"
            text: "Color change at warning thresholds"
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
            Kirigami.FormData.label: "Update Intervals"
        }

        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Update interval (seconds):"
            from: 1
            to: 60
            stepSize: 1
        }

        CheckBox {
            id: batModeCheck
            Kirigami.FormData.label: "Battery mode:"
            text: "Reduce refresh rate on battery power"
        }

        SpinBox {
            id: batModeIntervalSpin
            Kirigami.FormData.label: "Battery mode interval (seconds):"
            from: 1
            to: 60
            stepSize: 1
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Actions"
        }

        TextField {
            id: clickCommandField
            Kirigami.FormData.label: "Click command:"
            placeholderText: "wezterm -e htop"
        }
    }
}
