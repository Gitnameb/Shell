import QtQuick

// Anillo de progreso que bordea una ficha de app o un escritorio. Sigue el
// mismo lenguaje que el ejemplo web: un trazo de 2 px sobre un rectángulo
// redondeado, empezando arriba y avanzando en sentido horario. Con progress
// negativo no se dibuja nada.
Item {
    id: root

    property real progress: -1
    property color color: Theme.accent
    property real thickness: 2
    property real cornerRadius: 8

    visible: root.progress >= 0
    onProgressChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
    onCornerRadiusChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (root.progress < 0 || width <= 0 || height <= 0)
                return;

            const thickness = Math.max(1, root.thickness);
            const inset = thickness / 2;
            const x = inset;
            const y = inset;
            const w = width - thickness;
            const h = height - thickness;
            const radius = Math.max(0,
                Math.min(root.cornerRadius, w / 2, h / 2));

            // Contorno en el sentido de las agujas del reloj, empezando por
            // el centro del borde superior. Cada tramo guarda su longitud
            // para poder cortar el trazo en el porcentaje exacto.
            const commands = [];
            const addLine = (toX, toY) => {
                const fromX = commands.length > 0
                    ? commands[commands.length - 1].toX : width / 2;
                const fromY = commands.length > 0
                    ? commands[commands.length - 1].toY : y;
                commands.push({
                    type: "line",
                    toX: toX,
                    toY: toY,
                    length: Math.sqrt((toX - fromX) * (toX - fromX)
                        + (toY - fromY) * (toY - fromY))
                });
            };
            const addArc = (cx, cy, startAngle, endAngle) => {
                commands.push({
                    type: "arc",
                    cx: cx,
                    cy: cy,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    toX: cx + radius * Math.cos(endAngle),
                    toY: cy + radius * Math.sin(endAngle),
                    length: Math.abs(endAngle - startAngle) * radius
                });
            };

            const startX = width / 2;
            commands.push({ type: "move", toX: startX, toY: y, length: 0 });
            addLine(x + w - radius, y);
            if (radius > 0)
                addArc(x + w - radius, y + radius, -Math.PI / 2, 0);
            addLine(x + w, y + h - radius);
            if (radius > 0)
                addArc(x + w - radius, y + h - radius, 0, Math.PI / 2);
            addLine(x + radius, y + h);
            if (radius > 0)
                addArc(x + radius, y + h - radius, Math.PI / 2, Math.PI);
            addLine(x, y + radius);
            if (radius > 0)
                addArc(x + radius, y + radius, Math.PI, Math.PI * 1.5);
            addLine(startX, y);

            let perimeter = 0;
            for (let i = 0; i < commands.length; i++)
                perimeter += commands[i].length;

            let remaining = Math.max(0, Math.min(1, root.progress))
                * perimeter;
            if (remaining <= 0)
                return;

            ctx.beginPath();
            ctx.moveTo(commands[0].toX, commands[0].toY);

            for (let i = 1; i < commands.length && remaining > 0; i++) {
                const command = commands[i];
                if (command.length <= 0)
                    continue;

                if (command.type === "line") {
                    const previous = commands[i - 1];
                    const take = Math.min(remaining, command.length);
                    const ratio = take / command.length;
                    ctx.lineTo(previous.toX
                        + (command.toX - previous.toX) * ratio,
                        previous.toY + (command.toY - previous.toY) * ratio);
                    if (take < command.length)
                        break;
                    remaining -= take;
                } else {
                    const take = Math.min(remaining, command.length);
                    const sweep = (command.endAngle - command.startAngle)
                        * (take / command.length);
                    ctx.arc(command.cx, command.cy, command.radius,
                        command.startAngle,
                        command.startAngle + sweep, false);
                    if (take < command.length)
                        break;
                    remaining -= take;
                }
            }

            ctx.lineWidth = thickness;
            ctx.lineCap = "round";
            ctx.strokeStyle = root.color;
            ctx.stroke();
        }
    }
}
