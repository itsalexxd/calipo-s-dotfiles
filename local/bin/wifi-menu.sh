#!/bin/bash

# Escanear redes disponibles
nmcli device wifi rescan 2>/dev/null

# Obtener lista de redes (SSID, señal, seguridad) sin duplicados
NETWORKS=$(nmcli -f SSID,SIGNAL,SECURITY device wifi list | awk 'NR>1 && $1!="--" {print}' | sort -u -k1,1)

# Mostrar en wofi
SELECTED=$(echo "$NETWORKS" | wofi --dmenu --prompt="Redes WiFi" --width=450 --height=350)

if [ -z "$SELECTED" ]; then
    exit 0
fi

SSID=$(echo "$SELECTED" | awk '{print $1}')

# Verificar si ya existe una conexión guardada para esa red
if nmcli connection show | grep -q "$SSID"; then
    nmcli connection up "$SSID"
    notify-send "WiFi" "Conectado a $SSID"
else
    # Pedir contraseña con wofi (modo password oculta el texto)
    PASSWORD=$(wofi --dmenu --password --prompt="Contraseña para $SSID")
    if [ -n "$PASSWORD" ]; then
        nmcli device wifi connect "$SSID" password "$PASSWORD"
        notify-send "WiFi" "Conectando a $SSID..."
    fi
fi
