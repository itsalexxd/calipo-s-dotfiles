#!/bin/bash
# ============================================================
# Regenera el archivo de colores GTK3 (Thunar) a partir de pywal.
# Se llama tras `wal -R` al cambiar el wallpaper.
#   ~/.cache/wal/colors        -> paleta (16 lineas hex)
#   ~/.config/gtk-3.0/thunar-pywal-colors.css  <- salida
# ============================================================
set -euo pipefail

WAL_COLORS="${HOME}/.cache/wal/colors"
OUT="${HOME}/.config/gtk-3.0/thunar-pywal-colors.css"

[ -f "$WAL_COLORS" ] || { echo "No existe $WAL_COLORS"; exit 1; }

# Leer los 16 colores
mapfile -t C < "$WAL_COLORS"
BG="${C[0]}"          # fondo
FG="${C[7]}"          # foreground (color7)
ACCENT="${C[4]}"      # acento (color4)
ACCENT2="${C[5]}"     # acento secundario (color5)

cat > "$OUT" <<EOF
/* ============================================================
   Thunar + diálogos de archivos GTK — tema minimalista (alexg)
   Transparencia sutil, acorde con Hyprland (radio 4 + blur).
   ------------------------------------------------------------
   NO EDITAR A MANO: lo regenera ~/.config/hypr/update_gtk_theme.sh
   al cambiar el wallpaper (pywal). Generado: $(date '+%F %T')
   ============================================================ */

@define-color th_bg        ${BG};
@define-color th_accent    ${ACCENT};
@define-color th_accent2   ${ACCENT2};
@define-color th_fg        ${FG};
EOF

echo "Colores GTK actualizados -> $OUT (bg=$BG accent=$ACCENT fg=$FG)"
