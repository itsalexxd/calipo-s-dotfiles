#!/bin/bash

# Los bordes de color estan DESACTIVADOS (border_size = 0 en hyprland.lua).
# Este script se mantiene porque se llama desde el autostart (wal -R), pero
# ya no inyecta colores: si se reactivaran los bordes, descomenta las lineas.

# source ~/.cache/wal/colors.sh
# C_ACTIVE="${color4//\#/}"
# C_INACTIVE="${background//\#/}"
# hyprctl keyword general:col.active_border "rgba(${C_ACTIVE}ff)"
# hyprctl keyword general:col.inactive_border "rgba(${C_INACTIVE}aa)"

# Aseguramos el estado sin borde de color (por si algo lo reescribe)
hyprctl keyword general:border_size 0 >/dev/null 2>&1
hyprctl keyword decoration:rounding 4 >/dev/null 2>&1
