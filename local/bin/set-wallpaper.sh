#!/bin/bash
# Uso: set-wallpaper.sh /ruta/a/imagen.jpg
WALLPAPER="$1"

if [ -z "$WALLPAPER" ]; then
    echo "Uso: set-wallpaper.sh /ruta/a/imagen.jpg"
    exit 1
fi

swww img "$WALLPAPER" --transition-type wipe --transition-duration 1
echo "$WALLPAPER" > ~/.cache/current_wallpaper
