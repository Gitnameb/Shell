import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Selector de DNS privado. El interruptor del centro de control decide entre
// automático (apagado) y el proveedor elegido (encendido). Aquí solo se elige
// el proveedor, se editan los servidores y se configura el comportamiento con
// las VPN.
ColumnLayout {
    id: root

    property bool active: false
    spacing: 7

    readonly property var providers: [
        { key: "cloudflare", label: "Cloudflare" },
        { key: "adguard", label: "AdGuard" },
        { key: "opendns", label: "OpenDNS" },
        { key: "cleanbrowsing", label: "CleanBrowsing" },
        { key: "quad9", label: "Quad9" },
        { key: "hostname", label: "Personalizado" },
        { key: "manual", label: "Servidores manuales" }
    ]

    onActiveChanged: {
        if (root.active)
            DnsState.refresh();
    }

    Component.onCompleted: {
        if (root.active)
            DnsState.refresh();
    }

    Text {
        Layout.fillWidth: true
        text: DnsState.loading
            ? "Leyendo configuración…"
            : (!DnsState.available
                ? "Falta systemd-resolved o el ayudante de DNS privado. "
                    + "Ejecuta el instalador."
                : (!DnsState.enabled
                    ? "DNS automático"
                    : (DnsState.vpnSuspended
                        ? "DNS privado desactivado por VPN"
                        : "DNS privado · " + DnsState.providerLabel)))
        color: !DnsState.available
            ? Theme.warning
            : (DnsState.enabled ? Theme.accent : Theme.faint)
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Repeater {
        model: root.providers

        delegate: Rectangle {
            id: providerRow

            required property var modelData

            readonly property bool selected:
                DnsState.provider === modelData.key

            Layout.fillWidth: true
            implicitHeight: 28
            radius: 7
            color: selected
                ? Theme.accentSoft
                : (providerMouse.containsMouse
                    ? Theme.hover : "transparent")
            border.width: 1
            border.color: selected ? Theme.accentLine : Theme.border

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 7
                }
                spacing: 7

                Rectangle {
                    implicitWidth: 12
                    implicitHeight: 12
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: providerRow.selected
                        ? Theme.accent : Theme.borderStrong

                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.accent
                        visible: providerRow.selected
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: providerRow.modelData.label
                    color: providerRow.selected ? Theme.accent : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: providerRow.selected
                        ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: providerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DnsState.selectProvider(providerRow.modelData.key)
            }
        }
    }

    TextField {
        id: hostnameField

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        visible: DnsState.provider === "hostname"
        text: DnsState.hostname
        placeholderText: "dns.ejemplo.com"
        color: Theme.text
        placeholderTextColor: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 10
        leftPadding: 8
        rightPadding: 8
        selectByMouse: true
        background: Rectangle {
            radius: 7
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
        onEditingFinished: DnsState.setHostname(text)
    }

    Text {
        Layout.fillWidth: true
        visible: DnsState.provider === "hostname"
        text: "Se comprueba el certificado del nombre. Si el servidor no admite "
            + "DoT, se queda sin resolución."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    TextField {
        id: manualV4

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        visible: DnsState.provider === "manual"
        text: DnsState.manual4
        placeholderText: "DNS IPv4 (ej. 1.1.1.1 1.0.0.1)"
        color: Theme.text
        placeholderTextColor: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 10
        leftPadding: 8
        rightPadding: 8
        selectByMouse: true
        background: Rectangle {
            radius: 7
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
        onEditingFinished: DnsState.setManualServers(
            manualV4.text, manualV6.text)
    }

    TextField {
        id: manualV6

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        visible: DnsState.provider === "manual"
        text: DnsState.manual6
        placeholderText: "DNS IPv6 (opcional)"
        color: Theme.text
        placeholderTextColor: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 10
        leftPadding: 8
        rightPadding: 8
        selectByMouse: true
        background: Rectangle {
            radius: 7
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
        onEditingFinished: DnsState.setManualServers(
            manualV4.text, manualV6.text)
    }

    Text {
        Layout.fillWidth: true
        visible: DnsState.provider === "manual"
        text: "DoT oportunista: cifra si el servidor lo admite y, si no, "
            + "continúa sin cifrar."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 26
        radius: 7
        color: DnsState.busy ? Theme.surfaceAlt : Theme.accentSoft
        border.width: 1
        border.color: DnsState.busy ? Theme.border : Theme.accentLine
        opacity: DnsState.busy ? 0.6 : 1

        Text {
            anchors.centerIn: parent
            text: DnsState.busy
                ? "Guardando…"
                : (DnsState.enabled ? "Aplicar" : "Guardar")
            color: DnsState.busy ? Theme.faint : Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
        }

        MouseArea {
            anchors.fill: parent
            enabled: !DnsState.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (DnsState.enabled)
                    DnsState.applyWith(hostnameField.text,
                        manualV4.text, manualV6.text);
                else
                    DnsState.saveWith(hostnameField.text,
                        manualV4.text, manualV6.text);
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 2
        color: Theme.border
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "Desactivado para VPN"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        ShellSwitch {
            checked: DnsState.disabledForVpn
            onToggled: DnsState.setDisabledForVpn(
                !DnsState.disabledForVpn)
        }
    }

    Text {
        Layout.fillWidth: true
        text: "Apaga el DNS privado mientras haya una VPN y lo restaura al "
            + "desconectarla."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        visible: DnsState.error.length > 0
        text: DnsState.error
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        visible: DnsState.notice.length > 0
            && DnsState.error.length === 0
        text: DnsState.notice
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }
}
