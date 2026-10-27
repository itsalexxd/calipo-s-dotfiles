#!/bin/bash
# Ajusta la frecuencia del panel eDP-1 según la alimentación:
#   - Con batería  -> 120 Hz
#   - Con corriente -> 144 Hz
# Se ejecuta una vez al iniciar y queda escuchando cambios de alimentación.

MON="eDP-1"
MODE_BAT="1920x1080@120"
MODE_AC="1920x1080@144"

# Evita múltiples instancias (p.ej. al recargar la config de Hyprland)
exec 9>/tmp/refresg.lock
flock -n 9 || exit 0

apply() {
	local desired now
	if [ "$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)" = "1" ]; then
		desired="$MODE_AC"
	else
		desired="$MODE_BAT"
	fi

	# Frecuencia actual del monitor (entero, sin decimales)
	now=$(hyprctl monitors -j 2>/dev/null |
		jq -r --arg m "$MON" '.[] | select(.name==$m) | .refreshRate' 2>/dev/null |
		cut -d. -f1)

	# Si no se pudo leer (Hyprland aún arrancando), no hacer nada
	[ -z "$now" ] && return

	if [ "${desired##*@}" != "$now" ]; then
		hyprctl eval "hl.monitor({ output = '$MON', mode = '$desired', position = '0x0', scale = '1' })" >/dev/null
	fi
}

apply

# Escucha cambios del adaptador de corriente (y de la batería, por si acaso)
udevadm monitor --udev --subsystem-match=power_supply |
	while read -r _; do apply; done
