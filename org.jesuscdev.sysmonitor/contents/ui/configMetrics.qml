import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_showCpu: cpuCheck.checked
    property alias cfg_showCpuTemp: cpuTempCheck.checked
    property alias cfg_showGpu: gpuCheck.checked
    property alias cfg_showGpuTemp: gpuTempCheck.checked
    property alias cfg_showRam: ramCheck.checked
    property alias cfg_showNet: netCheck.checked
    property alias cfg_showDisk: diskCheck.checked
    property alias cfg_showUptime: uptimeCheck.checked
    property alias cfg_showBat: batCheck.checked
    property alias cfg_showBatTime: batTimeCheck.checked

    Kirigami.FormLayout {
        width: root.availableWidth

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Visible Metrics"
        }

        CheckBox {
            id: cpuCheck
            Kirigami.FormData.label: "CPU:"
            text: "Show CPU usage"
        }

        CheckBox {
            id: cpuTempCheck
            Kirigami.FormData.label: "CPU temp (\u00B0C):"
            text: "Show CPU temperature"
        }

        CheckBox {
            id: gpuCheck
            Kirigami.FormData.label: "GPU:"
            text: "Show GPU usage"
        }

        CheckBox {
            id: gpuTempCheck
            Kirigami.FormData.label: "GPU temp (\u00B0C):"
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
    }
}
