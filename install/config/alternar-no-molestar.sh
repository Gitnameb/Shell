#!/bin/sh
# ALBA · Alternar «No molestar» (lo usa el atajo SUPER+N): sin tostadas.
# Los avisos siguen llegando, en silencio, y esperan en el centro.
# La barra mira este «interruptor» una vez por segundo.
ARCHIVO="$HOME/.config/alba/no-molestar"
mkdir -p "$HOME/.config/alba"
if [ -e "$ARCHIVO" ]; then
    rm -f "$ARCHIVO"
    echo "Barra ALBA: avisos DESPIERTOS (las tostadas vuelven)."
else
    : > "$ARCHIVO"
    echo "Barra ALBA: NO MOLESTAR (silencio; el centro sigue apuntando)."
fi
