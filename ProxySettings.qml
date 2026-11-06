import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Proxy por conexión. Cada perfil guardado puede usar el proxy del sistema,
// un PAC o servidores propios. El modo manual se guarda como un PAC generado
// en NetworkManager y, si la red está activa, también en environment.d.
ColumnLayout {
    id: root

    property bool active: false
    spacing: 6

    onActiveChanged: {
        if (root.active) {
            ProxyState.error = "";
            ProxyState.notice = "";
            ProxyState.envFile = "";
            ProxyState.refresh();
        } else {
            ProxyState.expandedUuid = "";
        }
    }

    Text {
        Layout.fillWidth: true
        text: "PROXY POR RED"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Text {
        Layout.fillWidth: true
        text: "Cada conexión guardada puede usar su propio proxy. El modo "
            + "manual se guarda como PAC; la red activa se exporta al iniciar "
            + "sesión."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Repeater {
        model: ProxyState.connections

        delegate: ColumnLayout {
            id: proxyRow

            required property var modelData

            readonly property bool open: ProxyState.expandedUuid
                === String(modelData.uuid || "")
            readonly property bool usb: {
                const name = String(proxyRow.modelData.device || "").toLowerCase();
                return name.indexOf("usb") === 0
                    || name.indexOf("enx") === 0
                    || name.indexOf("rndis") === 0;
            }
            readonly property string summary: {
                const method = String(proxyRow.modelData.proxyMethod || "none");
                if (method === "auto")
                    return "Automático";
                if (method !== "manual")
                    return "Sin proxy";
                const parts = [];
                if (proxyRow.modelData.proxyHttp)
                    parts.push("HTTP");
                if (proxyRow.modelData.proxyHttps)
                    parts.push("HTTPS");
                if (proxyRow.modelData.proxySocks)
                    parts.push("SOCKS");
                return parts.length > 0
                    ? "Manual · " + parts.join(" + ") : "Manual";
            }

            property string method: "none"

            Layout.fillWidth: true
            spacing: 4

            function loadValues(): void {
                const data = proxyRow.modelData;
                proxyRow.method = String(data.proxyMethod || "none");
                pacField.text = String(data.proxyPac || "");
                httpField.text = String(data.proxyHttp || "");
                httpsField.text = String(data.proxyHttps || "");
                socksField.text = String(data.proxySocks || "");
                noField.text = String(data.proxyNo || "");
            }

            function applyNow(): void {
                ProxyState.save(proxyRow.modelData.uuid, proxyRow.method,
                    pacField.text, httpField.text, httpsField.text,
                    socksField.text, noField.text);
            }

            Component.onCompleted: {
                if (proxyRow.open)
                    proxyRow.loadValues();
            }

            onOpenChanged: {
                if (proxyRow.open)
                    proxyRow.loadValues();
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 8
                color: proxyRow.open
                    ? Theme.surfaceAlt
                    : (proxyMouse.containsMouse
                        ? Theme.hover : "transparent")
                border.width: proxyRow.open ? 1 : 0
                border.color: Theme.border

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 8
                    }
                    spacing: 7

                    AlbaIcon {
                        source: AlbaIcons.src(proxyRow.modelData.kind === "wifi"
                            ? "wifi" : (proxyRow.usb ? "usb" : "wired"))
                        color: proxyRow.modelData.active
                            ? Theme.accent : Theme.muted
                        size: 16
                        fallback: "◌"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: proxyRow.modelData.label
                            color: proxyRow.modelData.active
                                ? Theme.accent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: proxyRow.modelData.active
                                ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (proxyRow.modelData.kind === "wifi"
                                    ? "Wi-Fi" : "Ethernet")
                                + (proxyRow.modelData.device
                                    ? " · " + proxyRow.modelData.device : "")
                                + " · " + proxyRow.summary
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: proxyRow.open ? "−" : "+"
                        color: proxyRow.open ? Theme.accent : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: proxyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ProxyState.toggle(proxyRow.modelData.uuid)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                visible: proxyRow.open
                spacing: 5

                Row {
                    spacing: 4

                    Rectangle {
                        implicitWidth: 62
                        implicitHeight: 22
                        radius: 6
                        color: proxyRow.method === "none"
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: 1
                        border.color: proxyRow.method === "none"
                            ? Theme.accentLine : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Sin proxy"
                            color: proxyRow.method === "none"
                                ? Theme.accent : Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: proxyRow.method === "none"
                                ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: proxyRow.method = "none"
                        }
                    }

                    Rectangle {
                        implicitWidth: 74
                        implicitHeight: 22
                        radius: 6
                        color: proxyRow.method === "auto"
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: 1
                        border.color: proxyRow.method === "auto"
                            ? Theme.accentLine : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Automático"
                            color: proxyRow.method === "auto"
                                ? Theme.accent : Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: proxyRow.method === "auto"
                                ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: proxyRow.method = "auto"
                        }
                    }

                    Rectangle {
                        implicitWidth: 58
                        implicitHeight: 22
                        radius: 6
                        color: proxyRow.method === "manual"
                            ? Theme.accentSoft : Theme.surfaceAlt
                        border.width: 1
                        border.color: proxyRow.method === "manual"
                            ? Theme.accentLine : Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "Manual"
                            color: proxyRow.method === "manual"
                                ? Theme.accent : Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: proxyRow.method === "manual"
                                ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                proxyRow.method = "manual";
                                httpField.forceActiveFocus();
                            }
                        }
                    }
                }

                TextField {
                    id: pacField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: proxyRow.method === "auto"
                    placeholderText: "URL del archivo PAC (http://…)"
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
                    onAccepted: proxyRow.applyNow()
                }

                TextField {
                    id: httpField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: proxyRow.method === "manual"
                    placeholderText: "HTTP (host:puerto)"
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
                    onAccepted: proxyRow.applyNow()
                }

                TextField {
                    id: httpsField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: proxyRow.method === "manual"
                    placeholderText: "HTTPS (opcional)"
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
                    onAccepted: proxyRow.applyNow()
                }

                TextField {
                    id: socksField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: proxyRow.method === "manual"
                    placeholderText: "SOCKS5 (opcional)"
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
                    onAccepted: proxyRow.applyNow()
                }

                TextField {
                    id: noField

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: proxyRow.method === "manual"
                    placeholderText: "Excepciones (localhost, .local, 10.*)"
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
                    onAccepted: proxyRow.applyNow()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        implicitWidth: 68
                        implicitHeight: 26
                        radius: 7
                        color: ProxyState.busy
                            ? Theme.surfaceAlt : Theme.accentSoft
                        border.width: 1
                        border.color: ProxyState.busy
                            ? Theme.border : Theme.accentLine
                        opacity: ProxyState.busy ? 0.6 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "Aplicar"
                            color: ProxyState.busy
                                ? Theme.faint : Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !ProxyState.busy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: proxyRow.applyNow()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: proxyRow.method === "manual"
                    text: "Se guarda como PAC en el perfil. Si esta red está "
                        + "activa, también se exporta a environment.d para la "
                        + "próxima sesión."
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: ProxyState.loading
        text: "Leyendo conexiones…"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
    }

    Text {
        Layout.fillWidth: true
        visible: !ProxyState.loading && ProxyState.connections.length === 0
        text: "No hay conexiones Wi-Fi o Ethernet guardadas."
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        visible: ProxyState.error.length > 0
        text: ProxyState.error
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }

    Text {
        Layout.fillWidth: true
        visible: ProxyState.notice.length > 0
            && ProxyState.error.length === 0
        text: ProxyState.notice
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 8
        wrapMode: Text.Wrap
    }
}
