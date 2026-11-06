import QtQuick

// Gráfico de barras compacto para el historial de CPU, GPU y red.
Item {
    id: root

    property var values: []
    property int slots: 32
    property real maxValue: 100
    property color barColor: Theme.accent
    property color emptyColor: Theme.surfaceAlt
    property int gap: 1

    implicitHeight: 32

    readonly property int start: Math.max(0, root.values.length - root.slots)

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: root.emptyColor
        opacity: 0.35
    }

    Repeater {
        model: root.slots

        Rectangle {
            required property int index

            readonly property int valueIndex: root.start + index
            readonly property real value: root.values.length > root.start
                && valueIndex < root.values.length
                ? (root.values[valueIndex] || 0) : 0
            readonly property real columnWidth: Math.max(1,
                (root.width - (root.slots - 1) * root.gap) / root.slots)

            x: index * (columnWidth + root.gap)
            width: columnWidth
            height: Math.max(1, root.height * Math.min(1,
                Math.max(0, value) / root.maxValue))
            y: root.height - height
            radius: Math.min(1.5, width / 2)
            color: valueIndex < root.values.length
                ? root.barColor : "transparent"
            opacity: valueIndex === root.values.length - 1 ? 1 : 0.55
        }
    }
}
