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
    property alias cfg_showClaude: claudeCheck.checked
    property alias cfg_claudeIntervalSec: claudeIntervalSpin.value
    property alias cfg_claudeWarnThreshold: claudeWarnSpin.value
    property alias cfg_claudeCritThreshold: claudeCritSpin.value
    property alias cfg_ccusageEnabled: ccusageCheck.checked
    property alias cfg_showCodex: codexCheck.checked
    property alias cfg_ccusagePath: ccusagePathField.text

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

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Claude Usage"
        }

        CheckBox {
            id: claudeCheck
            Kirigami.FormData.label: "Claude:"
            text: "Show Claude usage limits"
        }

        SpinBox {
            id: claudeIntervalSpin
            Kirigami.FormData.label: "Refresh (seconds):"
            from: 30
            to: 600
        }

        SpinBox {
            id: claudeWarnSpin
            Kirigami.FormData.label: "Amber at (%):"
            from: 0
            to: 100
        }

        SpinBox {
            id: claudeCritSpin
            Kirigami.FormData.label: "Red at (%):"
            from: 0
            to: 100
        }

        CheckBox {
            id: ccusageCheck
            Kirigami.FormData.label: "Cost stats:"
            text: "Show token/cost stats in popup (ccusage)"
        }

        CheckBox {
            id: codexCheck
            Kirigami.FormData.label: "Codex:"
            text: "Show Codex/ChatGPT usage (from last codex run)"
        }

        TextField {
            id: ccusagePathField
            Kirigami.FormData.label: "ccusage command:"
            Layout.fillWidth: true
        }
    }
}
