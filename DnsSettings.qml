import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ajuste de DNS de las conexiones activas. NetworkManager guarda el DNS por
// conexión, así que esta vista aplica la misma elección a las conexiones Wi-Fi
// y Ethernet conectadas en ese momento.
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
        if (DnsState.activeConnections.length === 0) {
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
        visible: DnsState.loading || DnsState.activeConnections.length === 0
        text: DnsState.loading
            ? "Leyendo conexiones…"
            : "Conecta una red Wi-Fi o Ethernet para cambiar su DNS."
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
            implicitWidth: 112
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
                text: DnsState.busy ? "Guardando…" : "Aplicar a conectadas"
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
        text: "Hay conexiones con DNS distinto. Al aplicar se unificarán "
            + "las que están activas."
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
}
