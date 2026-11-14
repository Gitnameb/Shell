#!/usr/bin/env bash
# AIMP para Linux en Umbriel.
#
# AIMP comprueba XDG_CURRENT_DESKTOP al arrancar y se niega a abrir si el
# escritorio no es GNOME, KDE, Cinnamon, Mate, Fly o XFCE. Este script crea
# lanzadores que le presentan GNOME solo a AIMP y a sus procesos hijos, copia
# las entradas de menú para que apunten a esos lanzadores y, si el compositor
# lo admite, excluye AIMP del piloto de render fijo.
#
# No instala AIMP, no pide sudo y no cambia la sesión: Umbriel y el resto de
# aplicaciones siguen viendo XDG_CURRENT_DESKTOP=umbriel.
#
# Uso:
#   ./scripts/aimp-umbriel.sh --dry-run
#   ./scripts/aimp-umbriel.sh
#   ./scripts/aimp-umbriel.sh --remove
#
# Documentación: AIMP.md

set -Eeuo pipefail

AIMP_DIR=${AIMP_DIR:-/opt/aimp}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
APPS_DIR=${APPS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/applications}
CONFIG_FILE=${UMBRIEL_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/umbriel/config.toml}

# Marca que identifica lo que ha creado este script. Sin ella no se sobrescribe
# ni se borra un archivo ajeno salvo que se pase --force.
MARKER="gestionado por scripts/aimp-umbriel.sh"
DESKTOP_MARKER="X-AIMP-Umbriel-Managed=true"

DRY_RUN=0
REMOVE=0
FORCE=0
EXCLUDE=1

log() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33maviso:\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
    exit 1
}

run() {
    printf '\033[2m$\033[0m'
    printf ' %q' "$@"
    printf '\n'
    if (( ! DRY_RUN )); then
        "$@"
    fi
}

usage() {
    cat <<'EOF'
Prepara AIMP para Linux en Umbriel.

Uso:
  ./scripts/aimp-umbriel.sh [opciones]

Opciones:
  --dry-run       Muestra lo que haría, sin tocar nada
  --remove        Quita los lanzadores, las entradas de menú y la exclusión
  --force         Sustituye o borra archivos que no creó este script
  --no-exclude    No toca fixed_render_exclude en la configuración de Umbriel
  -h, --help      Muestra esta ayuda

Variables de entorno:
  AIMP_DIR        Directorio de AIMP (por defecto /opt/aimp)
  BIN_DIR         Directorio de los lanzadores (por defecto ~/.local/bin)
  APPS_DIR        Directorio de las entradas .desktop
                  (por defecto ~/.local/share/applications)
  UMBRIEL_CONFIG  Configuración de Umbriel
                  (por defecto ~/.config/umbriel/config.toml)

Ejemplos:
  ./scripts/aimp-umbriel.sh --dry-run
  ./scripts/aimp-umbriel.sh
  ./scripts/aimp-umbriel.sh --no-exclude    # Umbriel sin soporte de la clave
  ./scripts/aimp-umbriel.sh --remove
EOF
}

while (( $# )); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --remove) REMOVE=1 ;;
        --force) FORCE=1 ;;
        --no-exclude) EXCLUDE=0 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "opción desconocida: $1 (usa --help)"
            ;;
    esac
    shift
done

if (( EUID == 0 )); then
    die "ejecútalo como tu usuario normal, no con sudo."
fi

# Cita un valor para un script /bin/sh sin depender de bash.
shell_quote() {
    printf "'%s'" "${1//\'/\'\\\'\'}"
}

is_managed() {
    grep -qF -- "$MARKER" "$1" 2>/dev/null ||
        grep -qF -- "$DESKTOP_MARKER" "$1" 2>/dev/null
}

# Crea un archivo con contenido ya calculado, respetando --dry-run y los
# permisos. Se escribe en un temporal y se mueve para no dejar nada a medias.
write_file() {
    local dest=$1 mode=$2 content=$3 tmp

    if (( DRY_RUN )); then
        printf '\033[2m# escribiría\033[0m %s\n' "$dest"
        return 0
    fi

    mkdir -p -- "$(dirname -- "$dest")"
    tmp=$(mktemp "$dest.XXXXXX")
    printf '%s\n' "$content" >"$tmp"
    chmod "$mode" "$tmp"
    mv -f -- "$tmp" "$dest"
}

wrapper_content() {
    local target
    target=$(shell_quote "$1")
    cat <<EOF
#!/bin/sh
# $MARKER — no editar a mano. Para quitarlo: --remove.
# AIMP solo acepta GNOME, KDE, Cinnamon, Mate, Fly o XFCE. La variable afecta
# a este proceso y a sus hijos; la sesión y el resto de apps siguen en Umbriel.
XDG_CURRENT_DESKTOP=GNOME exec $target "\$@"
EOF
}

install_wrapper() {
    local name=$1 target=$2 dest="$BIN_DIR/$1" content

    if [[ ! -x $target ]]; then
        warn "no encuentro $target; se omite el lanzador $name"
        return 0
    fi

    if [[ -e $dest ]] && ! is_managed "$dest" && (( ! FORCE )); then
        warn "$dest ya existe y no lo creó este script; se omite (usa --force para sustituirlo)"
        return 0
    fi

    content=$(wrapper_content "$target")
    write_file "$dest" 0755 "$content"
    (( DRY_RUN )) || log "lanzador listo: $dest -> $target"
}

# Reescribe las líneas Exec de una entrada .desktop para que usen los
# lanzadores. Conserva el resto del archivo y añade la marca de gestión.
install_desktop_entry() {
    local name=$1 src="/usr/share/applications/$1.desktop"
    local dest="$APPS_DIR/$1.desktop"

    if [[ ! -f $src ]]; then
        warn "no encuentro $src; se omite la entrada de menú $name"
        return 0
    fi

    if [[ -e $dest ]] && ! is_managed "$dest" && (( ! FORCE )); then
        warn "$dest ya existe y no lo creó este script; se omite (usa --force para sustituirlo)"
        return 0
    fi

    if (( DRY_RUN )); then
        printf '\033[2m# escribiría\033[0m %s (a partir de %s)\n' "$dest" "$src"
        return 0
    fi

    mkdir -p -- "$APPS_DIR"
    python3 - "$src" "$dest" "$DESKTOP_MARKER" \
        "$BIN_DIR/aimp" "$BIN_DIR/aimpac" "$BIN_DIR/aimpate" <<'PY'
import os
import re
import sys

src, dest, marker, *wrappers = sys.argv[1:]
paths = {os.path.basename(p).lower(): p for p in wrappers}

with open(src, encoding="utf-8") as fh:
    lines = fh.read().splitlines()

exec_re = re.compile(r"^(\s*Exec\s*=\s*)(\S+)(.*)$")
out = []
have_header = False
for line in lines:
    match = exec_re.match(line)
    if match:
        base = os.path.basename(match.group(2)).lower()
        if base in paths:
            line = match.group(1) + paths[base] + match.group(3)
    out.append(line)
    if line.strip() == "[Desktop Entry]":
        have_header = True

if marker not in out and have_header:
    out.insert(out.index("[Desktop Entry]") + 1, marker)

tmp = dest + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out) + "\n")
os.chmod(tmp, 0o644)
os.replace(tmp, dest)
PY

    log "entrada de menú lista: $dest"
}

# Añade o quita "aimp" de general.fixed_render_exclude sin reformatear el
# resto del archivo. Imprime el estado final: added, removed, unchanged o
# absent.
edit_exclude_python() {
    python3 - "$1" "$2" <<'PY'
import json
import re
import sys

path, action = sys.argv[1], sys.argv[2]

try:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
except FileNotFoundError:
    text = ""

lines = text.splitlines()
header_re = re.compile(r"^\s*\[\s*general\s*\]\s*(?:#.*)?$")
next_header_re = re.compile(r"^\s*\[[^\]]+\]")
key_re = re.compile(
    r"^(\s*)fixed_render_exclude\s*=\s*(\[[^\]]*\])(\s*(?:#.*)?)$"
)
string_re = re.compile(r'"((?:[^"\\]|\\.)*)"' + r"|'([^']*)'")


def parse_items(raw):
    items = []
    for match in string_re.finditer(raw):
        if match.group(1) is not None:
            try:
                items.append(json.loads('"' + match.group(1) + '"'))
            except ValueError:
                items.append(match.group(1))
        else:
            items.append(match.group(2))
    return items


def render(items):
    body = ", ".join(json.dumps(item, ensure_ascii=False) for item in items)
    return "[" + body + "]"


header = next((i for i, line in enumerate(lines) if header_re.match(line)), None)

if action == "add":
    if header is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(["[general]", 'fixed_render_exclude = ["aimp"]'])
        status = "added"
    else:
        end = next(
            (i for i in range(header + 1, len(lines)) if next_header_re.match(lines[i])),
            len(lines),
        )
        key = next(
            (i for i in range(header + 1, end) if key_re.match(lines[i])), None
        )
        if key is None:
            lines.insert(header + 1, 'fixed_render_exclude = ["aimp"]')
            status = "added"
        else:
            match = key_re.match(lines[key])
            items = parse_items(match.group(2))
            if any(item.lower() == "aimp" for item in items):
                status = "unchanged"
            else:
                items.append("aimp")
                lines[key] = (
                    match.group(1)
                    + "fixed_render_exclude = "
                    + render(items)
                    + match.group(3)
                )
                status = "added"
else:
    if header is None:
        status = "absent"
    else:
        end = next(
            (i for i in range(header + 1, len(lines)) if next_header_re.match(lines[i])),
            len(lines),
        )
        key = next(
            (i for i in range(header + 1, end) if key_re.match(lines[i])), None
        )
        if key is None:
            status = "absent"
        else:
            match = key_re.match(lines[key])
            items = [
                item
                for item in parse_items(match.group(2))
                if item.lower() != "aimp"
            ]
            if len(items) == len(parse_items(match.group(2))):
                status = "unchanged"
            elif items:
                lines[key] = (
                    match.group(1)
                    + "fixed_render_exclude = "
                    + render(items)
                    + match.group(3)
                )
                status = "removed"
            else:
                del lines[key]
                status = "removed"

if status in ("added", "removed"):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + ("\n" if lines else ""))

print(status)
PY
}

edit_exclude() {
    local action=$1 tmp status output

    if [[ ! -f $CONFIG_FILE ]] && [[ $action == remove ]]; then
        log "no hay $CONFIG_FILE; no queda exclusión que quitar"
        return 0
    fi

    tmp=$(mktemp "${TMPDIR:-/tmp}/umbriel-config.XXXXXX")
    if [[ -f $CONFIG_FILE ]]; then
        cp -- "$CONFIG_FILE" "$tmp"
    fi

    status=$(edit_exclude_python "$tmp" "$action")

    case "$status" in
        unchanged)
            if [[ $action == remove ]]; then
                log "AIMP no estaba excluido; sin cambios"
            else
                log "AIMP ya estaba excluido; sin cambios"
            fi
            rm -f -- "$tmp"
            return 0
            ;;
        absent)
            log "fixed_render_exclude no estaba en la configuración; sin cambios"
            rm -f -- "$tmp"
            return 0
            ;;
        added) log "añadida la exclusión de AIMP del render fijo" ;;
        removed) log "quitada la exclusión de AIMP del render fijo" ;;
        *) die "estado inesperado al editar la configuración: $status" ;;
    esac

    if (( DRY_RUN )); then
        local left=$CONFIG_FILE
        [[ -f $CONFIG_FILE ]] || left=/dev/null
        diff -u --label "$CONFIG_FILE" --label "$CONFIG_FILE (propuesto)" \
            "$left" "$tmp" || true
        rm -f -- "$tmp"
        return 0
    fi

    if command -v umbriel >/dev/null 2>&1; then
        if ! output=$(umbriel config validate -c "$tmp" 2>&1); then
            printf '%s\n' "$output" >&2
            rm -f -- "$tmp"
            die "la configuración resultante no valida; no se toca $CONFIG_FILE. Si tu Umbriel no conoce la clave, repite con --no-exclude"
        fi
    else
        warn "no encuentro umbriel; no puedo validar la configuración"
    fi

    mkdir -p -- "$(dirname -- "$CONFIG_FILE")"
    cat -- "$tmp" >"$CONFIG_FILE"
    rm -f -- "$tmp"
    log "configuración actualizada: $CONFIG_FILE"
}

install() {
    log "lanzadores en $BIN_DIR"
    run mkdir -p -- "$BIN_DIR"
    install_wrapper aimp "$AIMP_DIR/AIMP"
    install_wrapper aimpac "$AIMP_DIR/AIMPac"
    install_wrapper aimpate "$AIMP_DIR/AIMPate"

    log "entradas de menú en $APPS_DIR"
    run mkdir -p -- "$APPS_DIR"
    install_desktop_entry aimp
    install_desktop_entry aimpac
    install_desktop_entry aimpate

    if command -v update-desktop-database >/dev/null 2>&1; then
        run update-desktop-database "$APPS_DIR"
    else
        warn "no encuentro update-desktop-database; el menú puede tardar en actualizarse"
    fi

    if (( EXCLUDE )); then
        log "exclusión del render fijo"
        if command -v python3 >/dev/null 2>&1; then
            edit_exclude add
        else
            warn "falta python3; se omite la exclusión del render fijo"
        fi
    else
        log "exclusión del render fijo omitida (--no-exclude)"
    fi

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) warn "$BIN_DIR no está en PATH; el menú funciona, pero el comando «aimp» puede no encontrarse" ;;
    esac

    cat <<EOF

AIMP queda listo. Comprobaciones útiles:

  tr '\\0' '\\n' < /proc/\$(pgrep -x AIMP)/environ | grep XDG_CURRENT_DESKTOP
  umbriel windows | grep -i aimp

El diálogo «App can not be run on UMBRIEL on WAYLAND» no debe volver a salir.
EOF
}

remove() {
    local file names=(aimp aimpac aimpate) name

    log "quitando lanzadores"
    for name in "${names[@]}"; do
        file="$BIN_DIR/$name"
        [[ -e $file ]] || continue
        if ! is_managed "$file" && (( ! FORCE )); then
            warn "$file no lo creó este script; se omite (usa --force para borrarlo)"
            continue
        fi
        run rm -f -- "$file"
    done

    log "quitando entradas de menú"
    for name in "${names[@]}"; do
        file="$APPS_DIR/$name.desktop"
        [[ -e $file ]] || continue
        if ! is_managed "$file" && (( ! FORCE )); then
            warn "$file no lo creó este script; se omite (usa --force para borrarlo)"
            continue
        fi
        run rm -f -- "$file"
    done

    if command -v update-desktop-database >/dev/null 2>&1; then
        run update-desktop-database "$APPS_DIR"
    fi

    log "exclusión del render fijo"
    edit_exclude remove

    cat <<EOF

AIMP sigue instalado; solo se han quitado los lanzadores y la exclusión.
Para volver a prepararlo: ./scripts/aimp-umbriel.sh
EOF
}

if (( REMOVE )); then
    remove
else
    [[ -x $AIMP_DIR/AIMP ]] ||
        die "no encuentro $AIMP_DIR/AIMP. Instala AIMP para Linux o define AIMP_DIR=/ruta/a/aimp"
    install
fi
