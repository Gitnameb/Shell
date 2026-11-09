#!/usr/bin/env bash
# Instalador principal del shell sobre Debian 13 + Umbriel.
#
# Ejecuta este script como tu usuario normal (no con sudo). Él pedirá sudo
# cuando necesite instalar paquetes o escribir en el sistema.
#
# El trabajo está dividido en módulos para poder revisarlos o ejecutarlos
# por separado:
#
#   scripts/install-packages.sh     repositorios, paquetes y servicios
#   scripts/network.sh              red, Wi-Fi, hotspot, VPN y Bluetooth
#   scripts/install-user-config.sh  enlaces y configuración del HOME
#   scripts/install-umbriel-fork.sh compilación e instalación del fork
#
# Uso:
#   ./install.sh [opciones]
#
# Opciones:
#   --dry-run         Muestra los comandos sin ejecutar nada
#   --yes             No pide confirmación al empezar
#   --skip-packages   No instala paquetes (solo configura y compila)
#   --skip-fork       No compila ni instala el fork de Umbriel
#   --skip-config     No copia la configuración de usuario
#   --skip-network    No configura ni instala la red, VPN ni Bluetooth
#   --skip-disks      No añade los discos internos NTFS a /etc/fstab
#   --force-config    Reemplaza configuraciones existentes (hace copia .bak)
#   --with-firmware   Instala firmware y drivers de este equipo
#   -h, --help        Muestra esta ayuda

set -Eeuo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$REPO_DIR/scripts/lib/common.sh"

DRY_RUN=0
ASSUME_YES=0
SKIP_PACKAGES=0
SKIP_FORK=0
SKIP_CONFIG=0
SKIP_NETWORK=0
SKIP_DISKS=0
FORCE_CONFIG=0
WITH_FIRMWARE=0

usage() {
    cat <<'EOF'
Instalador del shell sobre Debian 13 + Umbriel.

Uso:
  ./install.sh [opciones]

Opciones:
  --dry-run         Muestra los comandos sin ejecutar nada
  --yes             No pide confirmación al empezar
  --skip-packages   No instala paquetes (solo configura y compila)
  --skip-fork       No compila ni instala el fork de Umbriel
  --skip-config     No copia la configuración de usuario
  --skip-network    No configura ni instala la red, VPN ni Bluetooth
  --skip-disks      No añade los discos internos NTFS a /etc/fstab
  --force-config    Reemplaza configuraciones existentes (hace copia .bak)
  --with-firmware   Instala firmware y drivers de este equipo
  -h, --help        Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --yes) ASSUME_YES=1; shift ;;
        --skip-packages) SKIP_PACKAGES=1; shift ;;
        --skip-fork) SKIP_FORK=1; shift ;;
        --skip-config) SKIP_CONFIG=1; shift ;;
        --skip-network) SKIP_NETWORK=1; shift ;;
        --skip-disks) SKIP_DISKS=1; shift ;;
        --force-config) FORCE_CONFIG=1; shift ;;
        --with-firmware) WITH_FIRMWARE=1; shift ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

require_normal_user

USER_NAME=$(id -un)
TARGET_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || die "No se pudo determinar el HOME de $USER_NAME."

if [[ ! -f /etc/debian_version ]] || ! grep -q '^ID=debian' /etc/os-release 2>/dev/null; then
    die "Este instalador está pensado para Debian 13 (trixie)."
fi

if (( ! ASSUME_YES && ! DRY_RUN )); then
    cat <<EOF

Se va a preparar el shell en este equipo:

  Usuario:   $USER_NAME
  HOME:      $TARGET_HOME
  Proyecto:  $REPO_DIR

Se instalarán paquetes con apt, se copiará configuración (sin sobrescribir la
existente salvo --force-config) y se compilará el fork de Umbriel. La sesión
actual no se reinicia sola.

EOF
    read -r -p "¿Continuar? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sS]$ ]] || die "Cancelado."
fi

if (( ! DRY_RUN )); then
    sudo -v || die "No se pudo obtener permiso de sudo."
fi

# ---------------------------------------------------------------------------
# Paquetes
# ---------------------------------------------------------------------------
if (( ! SKIP_PACKAGES )); then
    log "Instalando paquetes, repositorios y servicios."
    PKG_ARGS=()
    (( DRY_RUN )) && PKG_ARGS+=(--dry-run)
    (( WITH_FIRMWARE )) && PKG_ARGS+=(--with-firmware)
    "$REPO_DIR/scripts/install-packages.sh" "${PKG_ARGS[@]}"
else
    log "Se omiten los paquetes (--skip-packages)."
fi

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------
# Debian puede dejar la Ethernet en /etc/network/interfaces y NetworkManager
# la marca como «unmanaged». Además wpasupplicant solo es una recomendación
# de network-manager; sin él el Wi-Fi aparece como «unavailable».
if (( ! SKIP_NETWORK )); then
    log "Preparando NetworkManager para Ethernet y Wi-Fi."
    NET_ARGS=()
    (( DRY_RUN )) && NET_ARGS+=(--dry-run)
    (( SKIP_PACKAGES )) && NET_ARGS+=(--skip-packages)
    # La instalación puede ejecutarse en una Debian limpia, sin shell abierto.
    # No intentamos reiniciar Quickshell desde aquí; si ya lo tienes abierto y
    # ejecutas network.sh a mano, el script sí lo reinicia.
    NET_ARGS+=(--no-restart-shell)
    if (( DRY_RUN )); then
        # SUDO_USER simula lo que sudo define en la ejecución real; así el
        # dry-run también enseña la instalación del asistente de Ethernet.
        SUDO_USER="$USER_NAME" "$REPO_DIR/scripts/network.sh" "${NET_ARGS[@]}"
    else
        run_sudo "$REPO_DIR/scripts/network.sh" --yes "${NET_ARGS[@]}"
    fi
else
    log "Se omite la configuración de red (--skip-network)."
fi

# ---------------------------------------------------------------------------
# Configuración de usuario
# ---------------------------------------------------------------------------
if (( ! SKIP_CONFIG )); then
    log "Copiando la configuración de usuario."
    CFG_ARGS=()
    (( DRY_RUN )) && CFG_ARGS+=(--dry-run)
    (( FORCE_CONFIG )) && CFG_ARGS+=(--force-config)
    "$REPO_DIR/scripts/install-user-config.sh" "${CFG_ARGS[@]}"
else
    log "Se omite la configuración de usuario (--skip-config)."
fi

# ---------------------------------------------------------------------------
# Fork de Umbriel
# ---------------------------------------------------------------------------
if (( ! SKIP_FORK )); then
    log "Compilando e instalando el fork de Umbriel."
    if (( DRY_RUN )); then
        "$REPO_DIR/scripts/install-umbriel-fork.sh" --dry-run
    else
        "$REPO_DIR/scripts/install-umbriel-fork.sh" --yes
    fi
else
    log "Se omite el fork de Umbriel (--skip-fork)."
fi

# ---------------------------------------------------------------------------
# Discos internos
# ---------------------------------------------------------------------------
# Las unidades USB las monta udiskie. Aquí solo se preparan los NTFS internos
# con /etc/fstab, una vez, para que no pidan contraseña en cada arranque.
if (( ! SKIP_DISKS )); then
    log "Preparando los discos internos NTFS."
    if (( DRY_RUN )); then
        "$REPO_DIR/scripts/mount-disks.sh" --dry-run
    else
        run_sudo "$REPO_DIR/scripts/mount-disks.sh" --apply \
            || warn "No se pudieron montar todos los discos internos; revisa /etc/fstab."
    fi
else
    log "Se omite el montaje de discos internos (--skip-disks)."
fi

# La validación va después del fork: la plantilla usa los seis botones del
# binario parcheado, que el Umbriel estándar no conoce.
if [[ -f "$TARGET_HOME/.config/umbriel/config.toml" ]] \
    && command -v umbriel >/dev/null 2>&1; then
    log "Validando la configuración de Umbriel."
    run umbriel config validate -c "$TARGET_HOME/.config/umbriel/config.toml" \
        || warn "Umbriel no aceptó la configuración; revisa $TARGET_HOME/.config/umbriel/config.toml."
fi

# La copia buena se actualiza después del fork: la plantilla usa claves que el
# Umbriel estándar todavía no conoce.
if [[ -x "$TARGET_HOME/.local/bin/umbriel-config-guard" ]] \
    && [[ -f "$TARGET_HOME/.config/umbriel/config.toml" ]]; then
    log "Actualizando la copia buena de la configuración de Umbriel."
    run env UMBRIEL_CONFIG="$TARGET_HOME/.config/umbriel/config.toml" \
        "$TARGET_HOME/.local/bin/umbriel-config-guard" save \
        || warn "No se pudo actualizar config.toml.good; se usará la plantilla si hace falta."
fi

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
log "Comprobaciones rápidas."
for cmd in qs umbriel ddcutil nmcli; do
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '  ok  %s\n' "$cmd"
    else
        warn "No encuentro '$cmd' en PATH."
    fi
done

# El guardián repara config.toml antes de Umbriel. Si falta, una escritura
# incompleta puede volver a dejar el escritorio sin shell.
for file in "$TARGET_HOME/.local/bin/umbriel-config-guard" \
        "$TARGET_HOME/.local/bin/shell-config-set" \
        "$TARGET_HOME/.config/systemd/user/umbriel.service.d/50-config-guard.conf"; do
    if [[ -f "$file" ]]; then
        printf '  ok  %s\n' "${file#"$TARGET_HOME"/}"
    else
        warn "Falta $file; el escritorio podría quedar negro si config.toml se trunca."
    fi
done

if [[ -x "$TARGET_HOME/.local/bin/shell-config-set" ]]; then
    if "$TARGET_HOME/.local/bin/shell-config-set" --help >/dev/null 2>&1; then
        printf '  ok  shell-config-set responde\n'
    else
        warn "shell-config-set no responde; revisa python3 y el script."
    fi
fi

# Los iconos de red, micrófono y volumen son SVG propios: si falta alguno, la
# barra y las vistas caerían en iconos del tema y se verían distintos según la
# instalación.
for icon in globe globe-off wired wifi-1 wifi-2 wifi-3 wifi-none wifi-off \
        mic mic-off volume-1 volume-2 volume-3 volume-off \
        check eye eye-off plus usb dns; do
    if [[ -f "$REPO_DIR/icons/$icon.svg" ]]; then
        printf '  ok  icons/%s.svg\n' "$icon"
    else
        warn "Falta icons/$icon.svg; los iconos de red se verán distintos."
    fi
done

cat <<EOF

Instalación terminada.

Siguientes pasos:
  1. Cierra sesión y elige «Umbriel» en SDDM.
  2. Comprueba la barra, los escritorios, el brillo y las alarmas.
  3. Si algo falla, revisa INSTALACION.md y PENDIENTES.md.

El fork de Umbriel requiere cerrar sesión para cargarse. El instalador aparta
el binario oficial con dpkg-divert, así que 'apt upgrade' no debería pisarlo.
Si alguna vez quitas esa diversión, vuelve a ejecutar:

  ./scripts/install-umbriel-fork.sh
EOF
