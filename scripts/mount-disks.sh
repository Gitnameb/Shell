#!/usr/bin/env bash
# Monta los discos internos NTFS al arrancar mediante /etc/fstab.
#
# Uso:
#   ./scripts/mount-disks.sh --dry-run
#   sudo ./scripts/mount-disks.sh --apply
#   sudo ./scripts/mount-disks.sh --fs ntfs3 --apply
#   sudo ./scripts/mount-disks.sh --uninstall
#
# No toca el disco del sistema: solo particiones NTFS internas y no
# extraíbles. De las que ya están montadas solo gestiona las que pertenecen al
# bloque que él mismo escribe en /etc/fstab. Las unidades USB se dejan para
# udiskie.
set -Eeuo pipefail

PREFIX="/mnt"
FSTYPE="ntfs-3g"
MODE="dry-run"
WINDOWS_NAMES=0
LAZY_UNMOUNT=0
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
  --fs ntfs-3g|ntfs3 Sistema de archivos a usar (por defecto ntfs-3g).
                     ntfs3 es el driver del kernel y va bien en discos de
                     datos, pero NO en una biblioteca de Steam ya instalada:
                     ntfs-3g guardó los enlaces de los prefijos de Proton y de
                     los runtimes como archivos Interix, y con ntfs3 los juegos
                     no arrancan. Para una biblioteca nueva, ntfs3 sí crea
                     enlaces nativos.
  --windows-names    Prohíbe nombres no válidos en Windows. Rompe los prefijos
                     de Proton, que necesitan crear dosdevices/c:
  --lazy-unmount     Desmonta sin esperar a que se liberen los archivos; evita
                     que el apagado se quede colgado con el disco en uso
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
        --windows-names) WINDOWS_NAMES=1; shift ;;
        --lazy-unmount) LAZY_UNMOUNT=1; shift ;;
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

# Nombre de la unidad systemd de un punto de montaje. Los guiones se escapan
# (\x2d), así que /mnt/New-Volume es mnt-New\x2dVolume.mount.
mount_unit() {
    command -v systemd-escape >/dev/null 2>&1 ||
        fail "Falta systemd-escape; no se puede configurar el desmontaje."
    systemd-escape -p --suffix=mount "$1"
}

# Drop-in con LazyUnmount=yes: systemd suelta el montaje al instante y lo
# limpia cuando deja de estar ocupado, en vez de fallar y bloquear el apagado.
lazy_dropin() {
    printf '/etc/systemd/system/%s.d/10-lazy-unmount.conf' "$(mount_unit "$1")"
}

# Devuelve una lista TSV con uuid, etiqueta, dispositivo y punto de montaje.
# Incluye los discos internos no extraíbles con NTFS, estén o no montados: los
# que ya están montados solo se listan si pertenecen al bloque gestionado, para
# poder reaplicar opciones sin perder sus entradas de /etc/fstab.
list_disks() {
    local tmp
    tmp=$(mktemp)
    lsblk -J -o NAME,PATH,FSTYPE,UUID,LABEL,TYPE,RM,TRAN,MOUNTPOINTS >"$tmp"
    python3 - "$tmp" "$PREFIX" "$FSTAB" "$BEGIN_MARK" "$END_MARK" <<'PY'
import json
import re
import sys
from pathlib import Path

prefix = sys.argv[2]


def clean(value):
    text = re.sub(r"[^A-Za-z0-9._-]+", "-", str(value or ""))
    return text.strip("-") or "NTFS"


def managed_mounts(path, begin, end):
    """UUID -> punto de montaje de las entradas del bloque gestionado."""
    mounts = {}
    inside = False
    try:
        lines = Path(path).read_text(encoding="utf-8").splitlines()
    except OSError:
        return mounts
    for line in lines:
        text = line.strip()
        if text == begin:
            inside = True
            continue
        if text == end:
            inside = False
            continue
        if not inside or not text or text.startswith("#"):
            continue
        fields = text.split()
        if len(fields) >= 2 and fields[0].startswith("UUID="):
            mounts[fields[0][5:]] = fields[1]
    return mounts


managed = managed_mounts(sys.argv[3], sys.argv[4], sys.argv[5])


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
        uuid = node["uuid"]
        label = clean(node.get("label") or uuid[:8])
        mounts = [m for m in (node.get("mountpoints") or []) if m]
        if mounts:
            if uuid not in managed:
                continue
            print("\t".join([uuid, label, node.get("path", ""), managed[uuid]]))
            continue
        path = f"{prefix}/{label}"
        print("\t".join([uuid, label, node.get("path", ""), path]))


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
    for mount in "${old_mounts[@]}"; do
        dropin=$(lazy_dropin "$mount")
        rm -f "$dropin"
        rmdir "$(dirname "$dropin")" 2>/dev/null || true
    done
    systemctl daemon-reload || true
    for mount in "${old_mounts[@]}"; do
        umount "$mount" 2>/dev/null || true
        rmdir "$mount" 2>/dev/null || true
    done
    echo "Bloque eliminado. Copia de seguridad: $backup_file"
    exit 0
fi

mapfile -t disks < <(list_disks "$FSTAB" "$BEGIN_MARK" "$END_MARK")

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
declare -A new_options=()
block_lines=()
mounted_now=()
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    if [[ -n "${seen[$mount]:-}" ]]; then
        echo "Aviso: '$mount' ya está usado; se omite $device." >&2
        continue
    fi
    seen[$mount]=1
    # ntfs3 no resuelve los enlaces Interix que deja ntfs-3g. Proton lee
    # dosdevices/s: con readlink; con ntfs3 es un archivo normal, aborta con
    # EINVAL y el juego no llega a abrirse. Avisar antes de romper una
    # biblioteca de Steam que ya funciona.
    if [[ "$FSTYPE" == "ntfs3" ]]; then
        for steamapps in "$mount/steamapps" "$mount/SteamLibrary/steamapps"; do
            [[ -d "$steamapps/compatdata" ]] || continue
            if grep -rqs -m1 -a 'IntxLNK' \
                    "$steamapps"/compatdata/*/pfx/dosdevices 2>/dev/null; then
                msg="'$steamapps' tiene prefijos de Proton creados con ntfs-3g. ntfs3 no resuelve sus enlaces y los juegos no arrancarán; usa --fs ntfs-3g."
                if [[ "$MODE" == "apply" ]]; then
                    fail "$msg"
                else
                    printf 'Aviso: %s\n' "$msg" >&2
                fi
                break
            fi
        done
    fi
    findmnt -rn "$mount" >/dev/null 2>&1 && mounted_now+=("$mount")
    # x-gvfs-* lo lee GVfs (Thunar, Nautilus, PCManFM). Dolphin usa Solid/KIO
    # y no interpreta estas opciones; allí el punto se añade a Lugares.
    # windows_names prohíbe ':' en nombres nuevos, y Proton necesita crear
    # dosdevices/c: dentro del prefijo; por eso no se usa salvo que se pida.
    options="nofail,x-systemd.device-timeout=5s,uid=$owner_uid,gid=$owner_gid,umask=022"
    (( WINDOWS_NAMES )) && options+=",windows_names"
    options+=",x-gvfs-show,x-gvfs-name=$label"
    new_options["$mount"]="$options"
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
    if (( LAZY_UNMOUNT )); then
        printf '\nDesmontaje perezoso (LazyUnmount=yes):\n'
        for row in "${disks[@]}"; do
            IFS=$'\t' read -r uuid label device mount <<<"$row"
            printf '  %s\n' "$(lazy_dropin "$mount")"
        done
    fi
    printf '\nPara aplicar: sudo %s --apply\n' "$0"
    exit 0
fi

backup_file=$(backup)

# Opciones que tienen ahora las entradas gestionadas, para compararlas con las
# nuevas y avisar si hace falta remontar (mount -a no remonta lo ya montado).
declare -A old_options=()
while IFS=$'\t' read -r mount opts; do
    [[ -n "$mount" ]] && old_options["$mount"]="$opts"
done < <(
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { inside = 1; next }
        $0 == e { inside = 0; next }
        inside && $1 ~ /^UUID=/ && $2 ~ /^\// { print $2 "\t" $4 }
    ' "$FSTAB"
)

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

# Desmontaje perezoso opcional: systemd suelta el montaje al instante en vez de
# fallar cuando el disco sigue en uso, y así el apagado no se queda colgado.
for row in "${disks[@]}"; do
    IFS=$'\t' read -r uuid label device mount <<<"$row"
    dropin=$(lazy_dropin "$mount")
    if (( LAZY_UNMOUNT )); then
        tmp=$(mktemp)
        printf '[Mount]\n# Generado por scripts/mount-disks.sh; no editar a mano.\nLazyUnmount=yes\n' >"$tmp"
        install -d -m 755 "$(dirname "$dropin")"
        install -m644 "$tmp" "$dropin"
        rm -f "$tmp"
    else
        rm -f "$dropin"
        rmdir "$(dirname "$dropin")" 2>/dev/null || true
    fi
done

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

# mount -a no remonta lo que ya estaba montado: solo aplica el fstab a montajes
# nuevos. Si las opciones de una entrada cambiaron, se desmonta y se vuelve a
# montar aquí mismo, unidad a unidad. Si alguna está ocupada, se deja como
# estaba y se muestran las instrucciones manuales.
remount=()
for mount in "${mounted_now[@]}"; do
    if [[ "${old_options[$mount]:-}" != "${new_options[$mount]:-}" ]]; then
        remount+=("$mount")
    fi
done
manual=()
for mount in "${remount[@]}"; do
    if umount "$mount" 2>/dev/null && mount "$mount"; then
        printf '  ok  %s remontado\n' "$mount"
    else
        manual+=("$mount")
        failed=1
    fi
done
if (( ${#manual[@]} > 0 )); then
    printf '\nNo se pudo remontar (¿sigue abierto algún programa?):\n' >&2
    for mount in "${manual[@]}"; do
        printf '  sudo umount %s && sudo mount %s\n' "$mount" "$mount" >&2
    done
fi

printf '\nCopia de seguridad: %s\n' "$backup_file"
exit "$failed"
