import QtQuick
import QtQuick.Layouts

// Celda de dato para las vistas de rendimiento y red.
ColumnLayout {
    id: root

    property string title: ""
    property string value: ""
    property string detail: ""
    property color valueColor: Theme.text

    spacing: 0

    Text {
        Layout.fillWidth: true
        text: root.title.toUpperCase()
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 7
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
    }

    Text {
        Layout.fillWidth: true
        text: root.value
        color: root.valueColor
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        Layout.fillWidth: true
        text: root.detail
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        elide: Text.ElideRight
    }
}
