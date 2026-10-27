#!/usr/bin/env bash
# Guarda la ruta del wallpaper actual en un archivo legible por el greeter
# de greetd, para que la pantalla de inicio de sesión use el mismo fondo.
#
# Uso:
#   wallpaper-state.sh [ruta]   -> guarda la ruta indicada
#   wallpaper-state.sh          -> la obtiene de awww

set -euo pipefail

STATE="$HOME/02_Imagenes/Wallpapers/.current-wallpaper"

if [[ $# -ge 1 ]]; then
    path=$1
else
    path=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -n 1)
fi

[[ -n ${path:-} ]] || exit 0
[[ -f $path ]] || exit 0

printf '%s\n' "$path" > "$STATE"
chmod 644 "$STATE"
