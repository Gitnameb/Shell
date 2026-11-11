#!/bin/sh
set -eu
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Capturas"
mkdir -p "$dir"
file="$dir/captura-$(date +%Y%m%d-%H%M%S).png"
region="$(slurp)" || exit 1
grim -g "$region" "$file"
printf '%s\n' "$file"
