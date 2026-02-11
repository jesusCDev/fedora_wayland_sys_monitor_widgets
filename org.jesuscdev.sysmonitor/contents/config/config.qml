import QtQuick 2.0
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Metrics"
        icon: "view-statistics"
        source: "configMetrics.qml"
    }
    ConfigCategory {
        name: "Display"
        icon: "preferences-desktop-display"
        source: "configDisplay.qml"
    }
    ConfigCategory {
        name: "Alerts"
        icon: "dialog-warning"
        source: "configAlerts.qml"
    }
    ConfigCategory {
        name: "Colors"
        icon: "preferences-desktop-color"
        source: "configColors.qml"
    }
}
