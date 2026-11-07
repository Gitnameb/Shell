#!/bin/sh
# Alternar la posición de la barra: arriba ↔ abajo (lo usa SUPER+P).
# Solo anota la preferencia: la barra se muda sola en ~1 s, EN VIVO,
# sin reiniciarse (por eso este atajo nunca puede perder la barra).
ARCHIVO="$HOME/.config/shell/posicion"
mkdir -p "$HOME/.config/shell"
if [ "$(cat "$ARCHIVO" 2>/dev/null)" = "abajo" ]; then
    printf 'arriba\n' > "$ARCHIVO"
    echo "Barra: ARRIBA (se muda en ~1 segundo)."
else
    printf 'abajo\n' > "$ARCHIVO"
    echo "Barra: ABAJO (se muda en ~1 segundo)."
fi
