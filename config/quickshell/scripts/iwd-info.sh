#!/bin/bash
# Consulta el estado de iwd (WiFi) e imprime lineas "clave|dato|..." para
# el modulo WiFi del centro de control de quickshell.
#
# Lineas emitidas:
#   estado|<powered>|<scanning>|<state>
#   conectado|<hexname_tipo>            (hexname_tipo es "/" si no hay conexion)
#   red|<hexname>|<tipo>|<senal_dBm*100>|<conocida:0-1>|<conectada:0-1>

BUS=net.connman.iwd
ROOT=/net/connman/iwd/0
ST=/net/connman/iwd/0/4

powered=$(busctl get-property $BUS "$ROOT" $BUS.Adapter Powered 2>/dev/null | awk '{print $2}')
scanning=$(busctl get-property $BUS "$ST" $BUS.Station Scanning 2>/dev/null | awk '{print $2}')
state=$(busctl get-property $BUS "$ST" $BUS.Station State 2>/dev/null | sed 's/^s "\(.*\)"$/\1/')
echo "estado|${powered:-false}|${scanning:-false}|${state:-disconnected}"

conn=$(busctl get-property $BUS "$ST" $BUS.Station ConnectedNetwork 2>/dev/null | sed 's/^o "\(.*\)"$/\1/')
[ -z "$conn" ] && conn="/"
echo "conectado|${conn##*/}"

busctl --json=short call $BUS "$ST" $BUS.Station GetOrderedNetworks 2>/dev/null \
    | jq -r '.data[0][] | @tsv' 2>/dev/null | head -10 \
    | while IFS="$(printf '\t')" read -r path sig; do
        base=${path##*/}
        tipo=${base##*_}
        hex=${base%_*}
        conocida=$(busctl get-property $BUS "$path" $BUS.Network KnownNetwork 2>/dev/null | grep -c '"/net/')
        conectada=0
        [ "$base" = "${conn##*/}" ] && conectada=1
        echo "red|$hex|$tipo|$sig|$conocida|$conectada"
    done
