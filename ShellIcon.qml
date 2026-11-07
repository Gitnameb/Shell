import Quickshell
import QtQuick
import QtQuick.Effects

// Icono de widget con color de estado. Usa un icono real del tema (Breeze) y
// lo tiñe con MultiEffect, de modo que el color comunica el estado sin
// depender de emojis. Para iconos de apps o de la bandeja, usar Image normal.
Item {
    id: root

    property string name: ""
    property string fallbackName: ""
    property string source: ""
    property color color: Theme.text
    property real size: 16
    property string fallback: ""
    property bool tint: true
    // Los SVG se rasterizan al doble para que se vean nítidos al escalar.
    property int renderScale: 2

    readonly property string resolvedSource: {
        if (root.source.length > 0)
            return root.source;
        if (root.name.length > 0 && Quickshell.hasThemeIcon(root.name))
            return Quickshell.iconPath(root.name);
        if (root.fallbackName.length > 0
                && Quickshell.hasThemeIcon(root.fallbackName))
            return Quickshell.iconPath(root.fallbackName);
        return "";
    }
    readonly property bool ready: iconImage.status === Image.Ready

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: iconImage

        anchors.fill: parent
        source: root.resolvedSource
        sourceSize.width: Math.ceil(root.size * root.renderScale)
        sourceSize.height: Math.ceil(root.size * root.renderScale)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: false
    }

    // MultiEffect sustituye a ColorOverlay (Qt5Compat). Es el efecto nativo de
    // Qt 6, no rasteriza en CPU y evita depender de
    // qml6-module-qt5compat-graphicaleffects.
    MultiEffect {
        anchors.fill: parent
        source: iconImage
        colorization: 1.0
        colorizationColor: root.color
        visible: root.tint && root.ready
    }

    Image {
        anchors.fill: parent
        // Con tinte, el icono ya lo dibuja MultiEffect: no se carga dos veces.
        source: root.tint ? "" : root.resolvedSource
        sourceSize.width: Math.ceil(root.size * root.renderScale)
        sourceSize.height: Math.ceil(root.size * root.renderScale)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        visible: !root.tint && root.ready
    }

    Text {
        anchors.centerIn: parent
        visible: !root.ready && root.fallback.length > 0
        text: root.fallback
        color: root.color
        font.family: Theme.fontFamily
        font.pixelSize: Math.max(8, Math.round(root.size * 0.72))
        font.weight: Font.DemiBold
    }
}
