import QtQuick
import QtQuick.Layouts

// Vista de tráfico de red de la interfaz activa. Los totales y picos se
// acumulan desde que arranca el shell; «Reiniciar» los pone a cero.
ColumnLayout {
    id: root

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                spacing: 4

                ShellIcon {
                    name: "arrow-down"
                    color: Theme.info
                    size: 14
                }

                Text {
                    text: SystemStats.formatRate(SystemStats.netDown)
                    color: Theme.info
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            Text {
                text: "descarga ahora"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                spacing: 4

                ShellIcon {
                    name: "arrow-up"
                    color: Theme.accent
                    size: 14
                }

                Text {
                    text: SystemStats.formatRate(SystemStats.netUp)
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }

            Text {
                text: "subida ahora"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        HistoryBars {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            values: SystemStats.netHistoryDown
            maxValue: Math.max(1024, SystemStats.netPeakDown)
            barColor: Theme.info
        }

        HistoryBars {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            values: SystemStats.netHistoryUp
            maxValue: Math.max(1024, SystemStats.netPeakUp)
            barColor: Theme.accent
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 6
        columnSpacing: 8

        StatCell {
            Layout.fillWidth: true
            title: "Sesión"
            value: SystemStats.formatBytes(SystemStats.netSessionDown)
            detail: "descargado desde el inicio"
        }

        StatCell {
            Layout.fillWidth: true
            title: "Sesión"
            value: SystemStats.formatBytes(SystemStats.netSessionUp)
            detail: "subido desde el inicio"
        }

        StatCell {
            Layout.fillWidth: true
            title: "Pico de descarga"
            value: SystemStats.formatRate(SystemStats.netPeakDown)
            detail: "máximo observado"
        }

        StatCell {
            Layout.fillWidth: true
            title: "Pico de subida"
            value: SystemStats.formatRate(SystemStats.netPeakUp)
            detail: "máximo observado"
        }

        StatCell {
            Layout.fillWidth: true
            title: "Latencia"
            value: SystemStats.latencyBusy ? "…"
                : (SystemStats.netLatency >= 0
                    ? SystemStats.netLatency + " ms" : "—")
            detail: "ping al gateway"
            valueColor: SystemStats.latencyBusy ? Theme.faint
                : (SystemStats.netLatency >= 0
                    && SystemStats.netLatency <= 60 ? Theme.accent
                    : (SystemStats.netLatency >= 0
                        ? Theme.warning : Theme.faint))
        }

        StatCell {
            Layout.fillWidth: true
            title: "Interfaz"
            value: SystemStats.netInterface.length > 0
                ? SystemStats.netInterface : "—"
            detail: SystemStats.networkKindLabel()
        }

        StatCell {
            Layout.fillWidth: true
            title: "Dirección"
            value: SystemStats.netIp.length > 0 ? SystemStats.netIp : "—"
            detail: "IPv4 de la interfaz"
        }

        StatCell {
            Layout.fillWidth: true
            title: "Enlace"
            value: SystemStats.networkKindLabel()
            detail: SystemStats.networkAvailable
                ? "interfaz activa" : "sin ruta predeterminada"
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

        Text {
            Layout.fillWidth: true
            text: SystemStats.networkAvailable
                ? "Medido en la interfaz activa"
                : "No hay ninguna interfaz con ruta predeterminada"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8
            wrapMode: Text.Wrap
        }

        Text {
            text: "Reiniciar"
            color: resetMouse.containsMouse ? Theme.accent : Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 8

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SystemStats.resetNet()
            }
        }
    }
}
