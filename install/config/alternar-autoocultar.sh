#!/bin/sh
# Alternar el autoocultado de la barra (lo usa el atajo SUPER+B).
# La barra mira este «interruptor» una vez por segundo.
ARCHIVO="$HOME/.config/shell/autoocultar"
if [ -e "$ARCHIVO" ]; then
    rm -f "$ARCHIVO"
    echo "Barra: modo FIJA (siempre visible)."
else
    mkdir -p "$HOME/.config/shell"
    touch "$ARCHIVO"
    echo "Barra: modo AUTOOCULTO (roza su borde para verla)."
fi
