import QtQuick
import QtQuick.Layouts

// Vista de rendimiento compartida por Procesador y Gráficos. Los datos salen
// de SystemStats (lectura real de /proc y /sys), sin simulación.
ColumnLayout {
    id: root

    property string kind: "cpu"

    readonly property bool cpuMode: root.kind !== "gpu"
    readonly property real load: root.cpuMode
        ? SystemStats.cpuLoad : SystemStats.gpuLoad
    readonly property real temp: root.cpuMode
        ? SystemStats.cpuTemp : SystemStats.gpuTemp
    readonly property real peakTemp: root.cpuMode
        ? SystemStats.cpuPeakTemp : SystemStats.gpuPeakTemp
    readonly property real average: root.cpuMode
        ? SystemStats.cpuAverage : SystemStats.gpuAverage
    readonly property var history: root.cpuMode
        ? SystemStats.cpuHistory : SystemStats.gpuHistory
    readonly property color accent: root.temp >= 60
        ? SystemStats.thermalColor(root.temp) : Theme.accent

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: Math.round(root.load) + "%"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: "uso ahora"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            Text {
                Layout.fillWidth: true
                text: "media " + Math.round(root.average) + "%"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }

        Rectangle {
            implicitWidth: Math.max(48, tempChipText.implicitWidth + 16)
            implicitHeight: 26
            radius: 7
            color: root.temp >= 0
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                : Theme.surface
            border.width: 1
            border.color: root.temp >= 0
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.38)
                : Theme.border

            Text {
                id: tempChipText

                anchors.centerIn: parent
                // Actual / pico de esta sesión.
                text: root.temp >= 0
                    ? Math.round(root.temp) + "° / "
                        + Math.round(root.peakTemp) + "°"
                    : "—"
                color: root.temp >= 0 ? root.accent : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    HistoryBars {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        values: root.history
        maxValue: 100
        barColor: root.accent
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 6
        columnSpacing: 8

        StatCell {
            Layout.fillWidth: true
            title: "Temperatura"
            // Actual / pico máximo de esta sesión.
            value: root.temp >= 0
                ? Math.round(root.temp) + " / " + Math.round(root.peakTemp)
                    + " °C"
                : "—"
            detail: root.temp >= 0
                ? "actual / pico · " + SystemStats.thermalLabel(root.temp)
                : "sensor no disponible"
            valueColor: root.accent
        }

        StatCell {
            Layout.fillWidth: true
            title: "Frecuencia"
            value: root.cpuMode
                ? SystemStats.formatFrequency(SystemStats.cpuFreq)
                : SystemStats.formatFrequency(SystemStats.gpuFreq)
            detail: root.cpuMode
                ? "máx. " + SystemStats.formatFrequency(SystemStats.cpuMaxFreq)
                : "máx. " + SystemStats.formatFrequency(SystemStats.gpuMaxFreq)
        }

        StatCell {
            Layout.fillWidth: true
            visible: root.cpuMode
            title: "Núcleos"
            value: SystemStats.cpuCores.length > 0
                ? SystemStats.cpuCores.length : "—"
            detail: "carga por núcleo abajo"
        }

        StatCell {
            Layout.fillWidth: true
            visible: root.cpuMode
            title: "Carga media"
            value: Math.round(SystemStats.cpuAverage) + "%"
            detail: "historial de 32 s"
        }

        StatCell {
            Layout.fillWidth: true
            visible: !root.cpuMode
            title: "Potencia"
            value: SystemStats.gpuPower >= 0
                ? SystemStats.gpuPower.toFixed(1).replace(".", ",") + " W" : "—"
            detail: "consumo de la GPU"
        }

        StatCell {
            Layout.fillWidth: true
            visible: !root.cpuMode
            title: "Memoria de vídeo"
            value: SystemStats.formatVram()
            detail: "usada / total"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        visible: root.cpuMode

        HistoryBars {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            values: SystemStats.cpuCores
            slots: Math.max(1, SystemStats.cpuCores.length)
            maxValue: 100
            barColor: Theme.accent
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Carga por núcleo"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }

            Text {
                text: SystemStats.cpuCores.length + " hilos"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ShellSwitch {
            checked: SettingsState.showTemps
            onToggled: SettingsState.setShowTemps(!SettingsState.showTemps)
        }

        Text {
            Layout.fillWidth: true
            text: "Grados en la barra"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }

        Text {
            text: "Reiniciar picos"
            color: resetMouse.containsMouse ? Theme.accent : Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemStats.resetPerf(root.kind)
            }
        }
    }
}
