#!/bin/sh
# Alternar «No molestar» (lo usa el atajo SUPER+N): sin tostadas.
# Los avisos siguen llegando, en silencio, y esperan en el centro.
# La barra mira este «interruptor» una vez por segundo.
ARCHIVO="$HOME/.config/shell/no-molestar"
mkdir -p "$HOME/.config/shell"
if [ -e "$ARCHIVO" ]; then
    rm -f "$ARCHIVO"
    echo "Barra: avisos DESPIERTOS (las tostadas vuelven)."
else
    : > "$ARCHIVO"
    echo "Barra: NO MOLESTAR (silencio; el centro sigue apuntando)."
fi
