#!/bin/sh
# Layout de teclado activo en Hyprland.
# Salida: "<lista de layouts>|<indice del activo>"   p.ej. "es,us|1"
# La lista viene de input.kb_layout y el indice de "hyprctl devices".

layouts=$(hyprctl getoption input:kb_layout 2>/dev/null | head -n1 | sed 's/^str: *//')
idx=$(hyprctl devices 2>/dev/null | grep -m1 'active layout index' | sed 's/.*index: *//')

[ -z "$layouts" ] && exit 0

case "$idx" in
	''|*[!0-9]*) idx=0 ;;
esac

printf '%s|%s\n' "$layouts" "$idx"
