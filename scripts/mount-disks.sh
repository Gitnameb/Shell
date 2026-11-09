#!/usr/bin/env bash
# Monta los discos internos NTFS al arrancar mediante /etc/fstab.
#
# Uso:
#   ./scripts/mount-disks.sh --dry-run
#   sudo ./scripts/mount-disks.sh --apply
#   sudo ./scripts/mount-disks.sh --fs ntfs3 --apply
#   sudo ./scripts/mount-disks.sh --uninstall
#
# No toca el disco del sistema: solo particiones NTFS internas, no extraíbles
# y sin punto de montaje activo. Las unidades USB se dejan para udiskie.
set -Eeuo pipefail

PREFIX="/mnt"
FSTYPE="ntfs-3g"
MODE="dry-run"
FSTAB="${SHELL_FSTAB:-/etc/fstab}"
ONLY=()
EXCLUDE=()
BEGIN_MARK="# shell-disks: inicio"
END_MARK="# shell-disks: fin"

usage() {
    cat <<'EOF'
Monta los discos internos NTFS al arrancar.

Opciones:
  --dry-run          Muestra lo que haría (por defecto)
  --apply            Escribe /etc/fstab y monta
  --uninstall        Quita el bloque gestionado y desmonta esos puntos
  --fs ntfs-3g|ntfs3 Sistema de archivos a usar (por defecto ntfs-3g)
  --prefix RUTA      Carpeta base de los puntos de montaje (/mnt)
  --only ETIQUETA    Solo estos discos (UUID o etiqueta; repetible)
  --exclude ETIQUETA No montar estos discos (UUID o etiqueta; repetible)
  -h, --help         Muestra esta ayuda
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dry-run) MODE="dry-run"; shift ;;
        --apply) MODE="apply"; shift ;;
        --uninstall) MODE="uninstall"; shift ;;
        --fs)
            FSTYPE="${2:-}"
            shift 2
            ;;
        --prefix)
            PREFIX="${2:-}"
            shift 2
            ;;
        --only)
            ONLY+=("${2:-}")
            shift 2
            ;;
        --exclude)
            EXCLUDE+=("${2:-}")
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1" >&2
            exit 2
            ;;
    esac
done

case "$FSTYPE" in
    ntfs-3g | ntfs3) ;;
    *)
        echo "Sistema de archivos no válido: $FSTYPE" >&2
        exit 2
        ;;
esac
case "$PREFIX" in
    /*) ;;
    *)
        echo "El prefijo debe ser una ruta absoluta." >&2
        exit 2
        ;;
esac

if (( EUID != 0 )) && [[ "$MODE" != "dry-run" ]]; then
    echo "Ejecuta con sudo para aplicar los cambios." >&2
    exit 1
fi

owner_uid="${SUDO_UID:-$(id -u)}"
owner_gid="${SUDO_GID:-$(id -g)}"

backup() {
    local stamp backup_file
    stamp=$(date +%Y%m%d-%H%M%S)
    backup_file="$FSTAB.shell-$stamp"
    cp -a "$FSTAB" "$backup_file"
    printf '%s\n' "$backup_file"
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

# Devuelve una lista TSV con uuid, etiqueta, dispositivo y punto de montaje.
# Solo discos internos no extraíbles con NTFS y sin montar.
list_disks() {
    local tmp
    tmp=$(mktemp)
    lsblk -J -o NAME,PATH,FSTYPE,UUID,LABEL,TYPE,RM,TRAN,MOUNTPOINTS >"$tmp"
    python3 - "$tmp" "$PREFIX" <<'PY'
import json
import re
import sys
from pathlib import Path

prefix = sys.argv[2]


def clean(value):
    text = re.sub(r"[^A-Za-z0-9._-]+", "-", str(value or ""))
    return text.strip("-") or "NTFS"


def walk(nodes, inherited_tran="", inherited_rm=False):
    for node in nodes:
        tran = node.get("tran") or inherited_tran
        rm = bool(node.get("rm", inherited_rm))
        for child in node.get("children") or []:
            walk([child], tran, rm)
        if node.get("type") != "part":
            continue
        fstype = (node.get("fstype") or "").lower()
        if fstype != "ntfs":
            continue
        if rm or tran.lower() == "usb":
            continue
        if not node.get("uuid"):
            continue
        mounts = [m for m in (node.get("mountpoints") or []) if m]
        if mounts:
            continue
        label = clean(node.get("label") or node.get("uuid", "")[:8])
        path = f"{prefix}/{label}"
        print("\t".join([node["uuid"], label, node.get("path", ""), path]))


data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
walk(data.get("blockdevices", []))
PY
    rm -f "$tmp"
}

if [[ "$MODE" == "uninstall" ]]; then
    if ! grep -qF "$BEGIN_MARK" "$FSTAB"; then
        echo "No hay bloque de discos que quitar."
        exit 0
    fi
    mapfile -t old_mounts < <(
        awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
            $0 == b { inside = 1; next }
            $0 == e { inside = 0; next }
            inside && $2 ~ /^\// { print $2 }
        ' "$FSTAB"
    )
    backup_file=$(backup)
    python3 - "$FSTAB" "$BEGIN_MARK" "$END_MARK" <<'PY'
import sys
from pathlib import Path

path, begin, end = sys.argv[1:4]
lines = Path(path).read_text(encoding="utf-8").splitlines()
out = []
skip = False
for line in lines:
    if line.strip() == begin:
        skip = True
        continue
    if line.strip() == end:
        skip = False
        continue
    if not skip:
        out.append(line)
Path(path).write_text("\n".join(out).rstrip("\n") + "\n", encoding="utf-8")
PY
    systemctl daemon-reload || true
    for mount in "${old_mounts[@]}"; do
        umount "$mount" 2>/dev/null || true
        rmdir "$mount" 2>/dev/null || true
    done
    echo "Bloque eliminado. Copia de seguridad: $backup_file"
    exit 0
fi

mapfile -t disks < <(list_disks)

filter_value() {
    printf '%s' "$1" |
        sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

filter_disk() {
    local uuid="$1" label="$2" item value selected=0
    if (( ${#ONLY[@]} > 0 )); then
        for item in "${ONLY[@]}"; do
            value=$(filter_value "$item")
            if [[ "$value" == "$uuid" || "$value" == "$label" ]]; then
                selected=1
                break
            fi
        done
        (( selected )) || return 1
    fi
    for item in "${EXCLUDE[@]}"; do
        value=$(filter_value "$item")
        if [[ "$value" == "$uuid" || "$value" == "$label" ]]; then
            return 1
        fi
    done
    return 0
}

filtered=()
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    if filter_disk "$uuid" "$label"; then
        filtered+=("$row")
    fi
done
disks=("${filtered[@]}")

if (( ${#disks[@]} == 0 )); then
    echo "No se encontraron discos internos NTFS que coincidan con el filtro."
    exit 0
fi

printf 'Discos internos NTFS detectados:\n'
printf '  %-38s %-24s %s\n' "UUID" "Etiqueta" "Punto de montaje"
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    printf '  %-38s %-24s %s\n' "$uuid" "$label" "$mount"
done

declare -A seen
block_lines=()
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    if [[ -n "${seen[$mount]:-}" ]]; then
        echo "Aviso: '$mount' ya está usado; se omite $device." >&2
        continue
    fi
    seen[$mount]=1
    options="nofail,x-systemd.device-timeout=5s,uid=$owner_uid,gid=$owner_gid,umask=022,windows_names"
    block_lines+=("UUID=$uuid $mount $FSTYPE $options 0 0")
done

block=$(
    printf '%s\n' "$BEGIN_MARK"
    printf '# Generado por scripts/mount-disks.sh; no editar a mano.\n'
    printf '%s\n' "${block_lines[@]}"
    printf '%s\n' "$END_MARK"
)

if [[ "$MODE" == "dry-run" ]]; then
    printf '\nSe añadiría a %s:\n%s\n' "$FSTAB" "$block"
    printf '\nPuntos de montaje:\n'
    for row in "${disks[@]}"; do
        IFS=$'\t' read -r uuid label device mount <<<"$row"
        printf '  mkdir -p %s\n' "$mount"
    done
    printf '\nPara aplicar: sudo %s --apply\n' "$0"
    exit 0
fi

backup_file=$(backup)
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    install -d -m 755 "$mount"
    chown "$owner_uid:$owner_gid" "$mount"
done

python3 - "$FSTAB" "$BEGIN_MARK" "$END_MARK" "$block" <<'PY'
import sys
from pathlib import Path

path, begin, end, block = sys.argv[1:5]
text = Path(path).read_text(encoding="utf-8")
lines = text.splitlines()
out = []
skip = False
for line in lines:
    if line.strip() == begin:
        skip = True
        continue
    if line.strip() == end:
        skip = False
        continue
    if not skip:
        out.append(line)
while out and not out[-1].strip():
    out.pop()
out.extend(["", *block.splitlines()])
Path(path).write_text("\n".join(out) + "\n", encoding="utf-8")
PY

systemctl daemon-reload
if ! mount -a; then
    cp -a "$backup_file" "$FSTAB"
    systemctl daemon-reload
    fail "mount -a falló; se restauró $FSTAB desde $backup_file"
fi

failed=0
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    if findmnt -rn "$mount" >/dev/null 2>&1; then
        printf '  ok  %s\n' "$mount"
    else
        printf '  aviso  %s no quedó montado; revisa el disco.\n' "$mount" >&2
        failed=1
    fi
done

printf '\nCopia de seguridad: %s\n' "$backup_file"
exit "$failed"
