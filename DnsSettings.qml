import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ajuste global de DNS. NetworkManager guarda el DNS por conexión, así que
// esta vista aplica la misma elección a todas las redes Wi-Fi y Ethernet
// guardadas. Muestra debajo qué conexiones se verán afectadas.
ColumnLayout {
    id: root

    property bool active: false
    property bool autoMode: true
    spacing: 7

    onActiveChanged: {
        if (root.active) {
            DnsState.error = "";
            DnsState.notice = "";
            DnsState.refresh();
            root.loadFields();
        }
    }

    Component.onCompleted: {
        if (root.active)
            root.loadFields();
    }

    Connections {
        target: DnsState

        function onConnectionsChanged(): void {
            if (root.active)
                root.loadFields();
        }
    }

    function loadFields(): void {
        if (DnsState.connections.length === 0) {
            root.autoMode = true;
            dnsV4.text = "";
            dnsV6.text = "";
            return;
        }
        root.autoMode = DnsState.allAuto;
        dnsV4.text = DnsState.current4;
        dnsV6.text = DnsState.current6;
    }

    function applyNow(): void {
        DnsState.saveAll(root.autoMode, dnsV4.text, dnsV6.text);
    }

    Text {
        Layout.fillWidth: true
        text: "DNS GLOBAL"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Text {
        Layout.fillWidth: true
        text: "Se aplica a todas las redes Wi-Fi y Ethernet guardadas. "
            + "Los cambios no cortan la conexión."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Row {
        spacing: 4

        Rectangle {
            implicitWidth: 72
            implicitHeight: 22
            radius: 6
            color: root.autoMode
                ? Theme.accentSoft : Theme.surfaceAlt
            border.width: 1
            border.color: root.autoMode
                ? Theme.accentLine : Theme.border

            Text {
                anchors.centerIn: parent
                text: "Automático"
                color: root.autoMode ? Theme.accent : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: root.autoMode
                    ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.autoMode = true
            }
        }

        Rectangle {
            implicitWidth: 58
            implicitHeight: 22
            radius: 6
            color: !root.autoMode
                ? Theme.accentSoft : Theme.surfaceAlt
            border.width: 1
            border.color: !root.autoMode
                ? Theme.accentLine : Theme.border

            Text {
                anchors.centerIn: parent
                text: "Manual"
                color: !root.autoMode ? Theme.accent : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: !root.autoMode
                    ? Font.DemiBold : Font.Normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.autoMode = false;
                    dnsV4.forceActiveFocus();
                }
            }
        }
    }

    TextField {
        id: dnsV4

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        enabled: !root.autoMode
        opacity: root.autoMode ? 0.45 : 1
        placeholderText: "DNS IPv4 (ej. 1.1.1.1 9.9.9.9)"
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
        onAccepted: root.applyNow()
    }

    TextField {
        id: dnsV6

        Layout.fillWidth: true
        Layout.preferredHeight: 30
        enabled: !root.autoMode
        opacity: root.autoMode ? 0.45 : 1
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
        onAccepted: root.applyNow()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            implicitWidth: 96
            implicitHeight: 26
            radius: 7
            color: DnsState.busy
                ? Theme.surfaceAlt : Theme.accentSoft
            border.width: 1
            border.color: DnsState.busy
                ? Theme.border : Theme.accentLine
            opacity: DnsState.busy ? 0.6 : 1

            Text {
                anchors.centerIn: parent
                text: DnsState.busy ? "Guardando…" : "Aplicar a todas"
                color: DnsState.busy ? Theme.faint : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                enabled: !DnsState.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: root.applyNow()
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Text {
        Layout.fillWidth: true
        visible: DnsState.mixed && !DnsState.allAuto
        text: "Hay redes con DNS distinto. Al aplicar se unificarán todas."
        color: Theme.warning
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

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 2
        color: Theme.border
    }

    Text {
        Layout.fillWidth: true
        text: "AFECTA A"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Repeater {
        model: DnsState.connections

        delegate: RowLayout {
            id: dnsRow

            required property var modelData

            readonly property bool usb: {
                const name = String(dnsRow.modelData.device || "").toLowerCase();
                return name.indexOf("usb") === 0
                    || name.indexOf("enx") === 0
                    || name.indexOf("rndis") === 0;
            }
            readonly property string current: {
                if (dnsRow.modelData.auto)
                    return "Automático";
                const list = [];
                const v4 = dnsRow.modelData.dns4 || [];
                const v6 = dnsRow.modelData.dns6 || [];
                for (let i = 0; i < v4.length; i++)
                    list.push(v4[i]);
                for (let i = 0; i < v6.length; i++)
                    list.push(v6[i]);
                return list.length > 0 ? list.join(", ") : "Sin DNS";
            }

            Layout.fillWidth: true
            spacing: 7

            ShellIcon {
                source: ShellIcons.src(dnsRow.modelData.kind === "wifi"
                    ? "wifi" : (dnsRow.usb ? "usb" : "wired"))
                color: dnsRow.modelData.active
                    ? Theme.accent : Theme.muted
                size: 14
                fallback: "◌"
            }

            Text {
                Layout.fillWidth: true
                text: dnsRow.modelData.label
                color: dnsRow.modelData.active
                    ? Theme.accent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            Text {
                Layout.preferredWidth: 110
                text: dnsRow.current
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 8
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: !DnsState.loading && DnsState.connections.length === 0
        text: "No hay conexiones Wi-Fi o Ethernet guardadas."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }
}
