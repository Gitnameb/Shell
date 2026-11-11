#!/bin/sh
# Desactiva el autoencendido de BlueZ (AutoEnable=false).
#
# Uso: sudo scripts/bluetooth-boot-off.sh
#
# BlueZ enciende el adaptador al arrancar y no recuerda que el usuario lo
# apagó. Con AutoEnable=false, un Bluetooth apagado permanece apagado desde el
# arranque; el shell lo vuelve a encender al iniciar la sesión si la última vez
# quedó encendido (settings.conf → btEnabled).
#
# El cambio se aplica en el próximo arranque de bluetoothd. Si quieres
# aplicarlo ahora, reinicia el servicio a mano:
#   sudo systemctl restart bluetooth
# (eso desconecta los dispositivos Bluetooth conectados).

set -eu

conf=/etc/bluetooth/main.conf

if [ ! -f "$conf" ]; then
    echo "No existe $conf; ¿está instalado BlueZ?" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecuta este script con sudo." >&2
    exit 1
fi

if grep -qE '^[[:space:]]*AutoEnable[[:space:]]*=[[:space:]]*false' "$conf"; then
    echo "AutoEnable=false ya estaba configurado."
    exit 0
fi

if grep -qE '^[[:space:]]*AutoEnable[[:space:]]*=' "$conf"; then
    sed -i -E 's/^[[:space:]]*AutoEnable[[:space:]]*=.*/AutoEnable=false/' "$conf"
elif grep -qE '^\[Policy\][[:space:]]*$' "$conf"; then
    sed -i '/^\[Policy\][[:space:]]*$/a AutoEnable=false' "$conf"
else
    printf '\n[Policy]\nAutoEnable=false\n' >> "$conf"
fi

echo "AutoEnable=false escrito en $conf."
echo "Se aplicará en el próximo arranque de bluetoothd."
