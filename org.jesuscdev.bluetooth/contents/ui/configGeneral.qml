import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

ScrollView {
    id: root

    property alias cfg_pollIntervalSec: pollSpin.value
    property alias cfg_nameMaxChars: nameSpin.value
    property alias cfg_scanDurationSec: scanSpin.value

    Kirigami.FormLayout {
        width: root.availableWidth

        SpinBox {
            id: pollSpin
            Kirigami.FormData.label: "Refresh (seconds):"
            from: 2
            to: 60
        }

        SpinBox {
            id: nameSpin
            Kirigami.FormData.label: "Panel name length (chars):"
            from: 4
            to: 30
        }

        SpinBox {
            id: scanSpin
            Kirigami.FormData.label: "Scan duration (seconds):"
            from: 5
            to: 30
        }
    }
}
