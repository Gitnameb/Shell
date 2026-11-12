#!/usr/bin/env bash
# Regenera umbriel-edit.patch a partir del árbol del edit y de un clon de
# Umbriel que contenga el commit base (b6c4b7d por defecto).
#
# El repositorio del edit no comparte historia con upstream, así que no basta
# con `git diff b6c4b7d`: hay que comparar los árboles. El script crea un
# repositorio temporal, pone la base como primer commit, copia el árbol del
# edit encima y genera el parche. Antes de escribirlo comprueba que aplicado
# sobre la base reproduce exactamente el árbol del edit.
#
# Uso:
#   ./scripts/regenerate-umbriel-patch.sh --base ~/umbriel-upstream
#   ./scripts/regenerate-umbriel-patch.sh --base /ruta/umbriel --output /tmp/edit.patch

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE_DIR="${HOME}/umbriel-edit"
BASE_DIR=""
BASE_COMMIT="b6c4b7d"
OUTPUT="${REPO_DIR}/umbriel-edit.patch"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Regenera umbriel-edit.patch comparando el árbol del edit con la base de
Umbriel.

Uso:
  ./scripts/regenerate-umbriel-patch.sh --base DIR [opciones]

Opciones:
  --base DIR          Clon de Umbriel con el commit base (obligatorio)
  --source DIR        Árbol del edit (por defecto ~/umbriel-edit)
  --base-commit SHA   Commit base de Umbriel (por defecto b6c4b7d)
  --output FILE       Parche de salida (por defecto umbriel-edit.patch)
  -h, --help          Muestra esta ayuda

El parche se genera desde los commits del edit. Confirma cualquier cambio
pendiente antes de ejecutarlo.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --base) BASE_DIR=$2; shift 2 ;;
        --source) SOURCE_DIR=$2; shift 2 ;;
        --base-commit) BASE_COMMIT=$2; shift 2 ;;
        --output) OUTPUT=$2; shift 2 ;;
        -h | --help) usage; exit 0 ;;
        *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
done

[[ -n "$BASE_DIR" ]] || die "Falta --base DIR (clon de Umbriel)."
[[ -d "$SOURCE_DIR" ]] || die "No existe el árbol del edit: $SOURCE_DIR"
git -C "$BASE_DIR" rev-parse --git-dir >/dev/null 2>&1 \
    || die "$BASE_DIR no es un repositorio git."
git -C "$SOURCE_DIR" rev-parse --git-dir >/dev/null 2>&1 \
    || die "$SOURCE_DIR no es un repositorio git."
git -C "$BASE_DIR" cat-file -e "${BASE_COMMIT}^{commit}" 2>/dev/null \
    || die "El commit $BASE_COMMIT no está en $BASE_DIR."

tmp=$(mktemp -d "${TMPDIR:-/tmp}/umbriel-patch.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# 1. La base, como primer commit de un repositorio temporal.
git -C "$BASE_DIR" archive "$BASE_COMMIT" | tar -x -C "$tmp"
git -C "$tmp" init -q
git -C "$tmp" add -A
git -C "$tmp" -c user.email=patch@local -c user.name=patch commit -qm base

# 2. El árbol actual del edit encima. `git archive` solo incluye lo
# confirmado; un árbol sucio produciría un parche que no coincide con lo que
# se probó, así que se rechaza.
if [[ -n "$(git -C "$SOURCE_DIR" status --porcelain)" ]]; then
    die "Hay cambios sin confirmar en $SOURCE_DIR; confírmalos antes de regenerar."
fi
find "$tmp" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git -C "$SOURCE_DIR" archive HEAD | tar -x -C "$tmp"
git -C "$tmp" add -A

git -C "$tmp" diff --cached --binary >"$tmp/patch"

# 4. Verificación: aplicar sobre una copia limpia de la base debe dar el mismo
# árbol que el edit.
mkdir -p "$tmp/check" "$tmp/head"
git -C "$BASE_DIR" archive "$BASE_COMMIT" | tar -x -C "$tmp/check"
git -C "$tmp/check" init -q
git -C "$tmp/check" add -A
git -C "$tmp/check" -c user.email=patch@local -c user.name=patch commit -qm base
if ! git -C "$tmp/check" apply "$tmp/patch"; then
    die "El parche generado no se aplica sobre $BASE_COMMIT."
fi
git -C "$SOURCE_DIR" archive HEAD | tar -x -C "$tmp/head"
if ! diff -rq --exclude=.git "$tmp/check" "$tmp/head" >/dev/null; then
    diff -rq --exclude=.git "$tmp/check" "$tmp/head" >&2 || true
    die "El parche aplicado no reproduce el árbol del edit."
fi

mv "$tmp/patch" "$OUTPUT"
printf 'Parche escrito en %s (%s archivos).\n' \
    "$OUTPUT" "$(grep -c '^diff --git' "$OUTPUT")"
