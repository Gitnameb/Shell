#!/bin/sh
# ALBA · Alternar el autoocultado de la barra (lo usa el atajo SUPER+B).
# La barra mira este «interruptor» una vez por segundo.
ARCHIVO="$HOME/.config/alba/autoocultar"
if [ -e "$ARCHIVO" ]; then
    rm -f "$ARCHIVO"
    echo "Barra ALBA: modo FIJA (siempre visible)."
else
    mkdir -p "$HOME/.config/alba"
    touch "$ARCHIVO"
    echo "Barra ALBA: modo AUTOOCULTO (roza su borde para verla)."
fi
