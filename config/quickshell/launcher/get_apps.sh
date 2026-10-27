#!/bin/bash
# ------------------------------------------------------------------
# Lista las aplicaciones instaladas para el launcher de Quickshell.
# Salida (una app por línea):  Nombre <TAB> Ejecutar <TAB> RutaIcono
#
#  * Solo entradas [Desktop Entry] de tipo Application.
#  * Se descartan Hidden=true, NoDisplay=true y las entradas huérfanas
#    (el binario ya no existe) -> así no salen apps desinstaladas.
#  * El icono se resuelve a una RUTA REAL usando el tema de iconos del
#    sistema (el mismo que usan GTK y fuzzel). Qt, por su parte, usa el
#    tema "hicolor", por eso el nombre suelto (p.ej. "java") no se
#    encontraba y los iconos no se veían.
# ------------------------------------------------------------------

set -u

APP_DIRS=("$HOME/.local/share/applications"
          "/usr/share/applications"
          "/var/lib/flatpak/exports/share/applications"
          "$HOME/.local/share/flatpak/exports/share/applications")

ICON_BASES=("$HOME/.local/share/icons"
            "$HOME/.icons"
            "/usr/share/icons"
            "/var/lib/flatpak/exports/share/icons")

# Carpetas por defecto (si un tema no declara "Directories=").
ICON_SUBDIRS=("apps/scalable" "scalable/apps"
              "apps/128x128" "128x128/apps"
              "apps/64x64"  "64x64/apps"
              "apps/48x48"  "48x48/apps"
              "apps/32x32"  "32x32/apps"
              "apps/24x24"  "24x24/apps"
              "apps/22x22"  "22x22/apps"
              "apps/16x16"  "16x16/apps"
              "apps/256x256" "256x256/apps"
              "apps/512x512" "512x512/apps"
              "apps")

# ------------------------------------------------------------------
# 1. Tema de iconos (GTK/fuzzel) + temas heredados
# ------------------------------------------------------------------
icon_theme() {
    local t="" ini
    for ini in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        [ -f "$ini" ] || continue
        t=$(sed -n 's/^gtk-icon-theme-name[[:space:]]*=[[:space:]]*//p' "$ini" | head -n1)
        [ -n "$t" ] && break
    done
    if [ -z "$t" ]; then
        t=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    fi
    [ -z "$t" ] && t="hicolor"
    printf '%s\n' "$t"
}

theme_chain() {
    local first="$1" t base inh x
    local -a chain=() queue=("$first" "Papirus-Dark" "Papirus" "hicolor")
    local -A seen=()
    while [ "${#queue[@]}" -gt 0 ]; do
        t="${queue[0]}"
        queue=("${queue[@]:1}")
        [ -n "$t" ] || continue
        [ -z "${seen[$t]:-}" ] || continue
        seen["$t"]=1
        chain+=("$t")
        for base in "${ICON_BASES[@]}"; do
            [ -f "$base/$t/index.theme" ] || continue
            inh=$(sed -n 's/^Inherits=//p' "$base/$t/index.theme" | head -n1)
            for x in ${inh//,/ }; do
                queue+=("$x")
            done
            break
        done
    done
    printf '%s\n' "${chain[@]}"
}

# Carpetas que declara el tema en su index.theme (Directories=).
theme_dirs() {
    local theme="$1" base f
    for base in "${ICON_BASES[@]}"; do
        f="$base/$theme/index.theme"
        [ -f "$f" ] || continue
        awk '
            /^Directories=/ {
                sub(/^Directories=/, "")
                buf = $0
                while (buf ~ /,[[:space:]]*$/) {
                    if ((getline line) <= 0) break
                    buf = buf line
                }
                print buf
                exit
            }
        ' "$f" | tr ',' '\n' | sed 's/[[:space:]]//g' | grep -v '^$'
        return 0
    done
    printf '%s\n' "${ICON_SUBDIRS[@]}"
}

# ------------------------------------------------------------------
# 2. Lectura de los .desktop
# ------------------------------------------------------------------
files=()
for d in "${APP_DIRS[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$d" -maxdepth 3 -name '*.desktop' -type f 2>/dev/null | sort)
done

[ "${#files[@]}" -gt 0 ] || exit 0

parsed=$(awk '
function emit() {
    if (id == "") return
    if (type != "" && type != "Application") return
    if (hidden == "true") return
    if (nodisplay == "true") return
    if (name == "" && namees == "") return
    if (exec == "") return
    tmark = "F"
    if (term == "true") tmark = "T"
    print id "\t" (namees != "" ? namees : name) "\t" exec "\t" icon "\t" tryexec "\t" tmark
}
FNR == 1 {
    if (started) emit()
    started = 1
    inentry = 0
    id = ""; name = ""; namees = ""; exec = ""; icon = ""; tryexec = ""; term = ""
    hidden = ""; nodisplay = ""; type = ""
    split(FILENAME, parts, "/")
    id = parts[length(parts)]
    sub(/\.desktop$/, "", id)
}
/^\[Desktop Entry\]/ { inentry = 1; next }
/^\[/ { inentry = 0 }
inentry {
    if ($0 ~ /^Name=/)            { if (name == "")   name = substr($0, 6) }
    else if ($0 ~ /^Name\[es/)     { if (namees == "") namees = substr($0, index($0, "]") + 2) }
    else if ($0 ~ /^Exec=/)        { if (exec == "")   exec = substr($0, 6) }
    else if ($0 ~ /^Icon=/)        { if (icon == "")   icon = substr($0, 6) }
    else if ($0 ~ /^TryExec=/)     { if (tryexec == "") tryexec = substr($0, 9) }
    else if ($0 ~ /^Type=/)        { if (type == "")   type = substr($0, 6) }
    else if ($0 ~ /^Hidden=/)      { if (hidden == "") hidden = substr($0, 8) }
    else if ($0 ~ /^NoDisplay=/)   { if (nodisplay == "") nodisplay = substr($0, 11) }
    else if ($0 ~ /^Terminal=/)    { if (term == "") { t = substr($0, 10); gsub(/\r/, "", t); gsub(/ /, "", t); term = tolower(t) } }
}
END { if (started) emit() }
' "${files[@]}")

# ------------------------------------------------------------------
# 3. Filtrado: entradas realmente instaladas + deduplicación
# ------------------------------------------------------------------
bin_exists() {
    local bin="$1"
    [ -n "$bin" ] || return 1
    case "$bin" in
        */*) [ -x "$bin" ] ;;
        *)   command -v "$bin" >/dev/null 2>&1 ;;
    esac
}

# Primer binario de la línea Exec (saltando "env VAR=valor ...").
first_bin() {
    local cmd="$1"
    local -a words=()
    read -r -a words <<< "$cmd"
    local i=0 w
    while [ "$i" -lt "${#words[@]}" ]; do
        w="${words[$i]}"
        w="${w%\"}"; w="${w#\"}"
        case "$w" in
            env|/usr/bin/env)
                i=$((i + 1))
                while [ "$i" -lt "${#words[@]}" ]; do
                    w="${words[$i]}"
                    w="${w%\"}"; w="${w#\"}"
                    case "$w" in
                        [A-Za-z_]*=*) i=$((i + 1)) ;;
                        *) break ;;
                    esac
                done
                ;;
            *) printf '%s\n' "$w"; return ;;
        esac
    done
    return 1
}

# Quita los códigos de campo de la especificación (%f, %U, %u, %i, ...).
strip_fieldcodes() {
    printf '%s\n' "$1" | sed -E 's/%[fFuUdDnNickvmM]//g; s/[[:space:]]+/ /g; s/^ //; s/ $//; s/=$//'
}

declare -A seen_id=()
apps=()
while IFS=$'\t' read -r id name exec icon tryexec term _rest; do
    [ -n "${id:-}" ] || continue
    [ -z "${seen_id[$id]:-}" ] || continue
    seen_id["$id"]=1

    # Corregir desplazamiento por campos vacíos
    if [ -z "${term:-}" ] && ([ "${tryexec:-}" = "T" ] || [ "${tryexec:-}" = "F" ]); then
        term="$tryexec"
        tryexec=""
    fi

    # TryExec: si está, el binario debe existir o la entrada se descarta.
    if [ -n "${tryexec:-}" ] && [ "${tryexec}" != "F" ] && [ "${tryexec}" != "T" ] && [ ${#tryexec} -gt 1 ]; then
        bin_exists "$tryexec" || continue
    fi

    cmd=$(strip_fieldcodes "$exec")
    [ -n "$cmd" ] || continue

    bin=$(first_bin "$cmd") || continue
    bin_exists "$bin" || continue

    # Si es una app de terminal, abrir con kitty
    if [ "${term:-}" = "T" ]; then
        cmd="kitty -- $cmd"
    fi

    apps+=("${name}"$'\t'"${cmd}"$'\t'"${icon}")
done <<< "$parsed"

[ "${#apps[@]}" -gt 0 ] || exit 0

# ------------------------------------------------------------------
# 4. Iconos: nombre -> ruta real (tema del sistema)
# ------------------------------------------------------------------
# Se busca por nombre (stat) en vez de recorrer las carpetas enteras:
# así sólo se miran los ~30 iconos que nos interesan.
declare -A THEME_DIRS=()

size_penalty() {
    local m="$1"
    if [ "$m" -ge 512 ]; then echo 10
    elif [ "$m" -ge 256 ]; then echo 9
    elif [ "$m" -ge 128 ]; then echo 1
    elif [ "$m" -ge 96 ]; then echo 2
    elif [ "$m" -ge 64 ]; then echo 3
    elif [ "$m" -ge 48 ]; then echo 4
    elif [ "$m" -ge 32 ]; then echo 5
    elif [ "$m" -ge 24 ]; then echo 6
    elif [ "$m" -ge 22 ]; then echo 7
    else echo 8
    fi
}

cat_penalty() {
    case "$1" in
        */apps|*/apps/*)      echo 0 ;;
        */devices|*/devices/*) echo 1 ;;
        */status|*/status/*)  echo 2 ;;
        */actions|*/actions/*) echo 3 ;;
        */places|*/places/*)  echo 4 ;;
        */mimetypes|*/mimetypes/*) echo 5 ;;
        */categories|*/categories/*) echo 6 ;;
        *) echo 7 ;;
    esac
}

# Devuelve la mejor ruta para un nombre de icono ("" si no existe).
resolve_icon() {
    local name="$1" theme base sub dir ext cand best="" best_score=999999
    local dsize scat sext score
    local -a chain=("${CHAIN[@]}")

    for theme in "${chain[@]}"; do
        if [ -z "${THEME_DIRS[$theme]:-}" ]; then
            THEME_DIRS["$theme"]=$(theme_dirs "$theme" | tr '\n' ' ')
        fi
        for base in "${ICON_BASES[@]}"; do
            [ -d "$base/$theme" ] || continue
            for sub in ${THEME_DIRS[$theme]}; do
                dir="$base/$theme/$sub"
                [ -d "$dir" ] || continue
                for ext in svg png xpm; do
                    cand="$dir/$name.$ext"
                    [ -f "$cand" ] || continue
                    dsize="${sub##*/}"
                    case "$dsize" in
                        scalable) scat=0 ;;
                        *x*) scat=$(size_penalty "${dsize%%x*}") ;;
                        [0-9]*) scat=$(size_penalty "$dsize") ;;
                        *) scat=5 ;;
                    esac
                    case "$ext" in svg) sext=0 ;; png) sext=1 ;; *) sext=2 ;; esac
                    score=$(($(cat_penalty "$sub") * 1000 + sext * 100 + scat))
                    if [ "$score" -lt "$best_score" ]; then
                        best_score=$score
                        best="$cand"
                    fi
                done
            done
        done
        # El primer tema que tiene el icono manda (prioridad del tema).
        [ -n "$best" ] && break
    done
    printf '%s\n' "$best"
}

declare -A icon_of=()
mapfile -t CHAIN < <(theme_chain "$(icon_theme)")

for entry in "${apps[@]}"; do
    icon="${entry##*$'\t'}"
    [ -n "$icon" ] || continue
    case "$icon" in
        /*) [ -f "$icon" ] && icon_of["$icon"]="$icon" ;;
        *)  [ -n "${icon_of[$icon]:-}" ] || icon_of["$icon"]=$(resolve_icon "$icon") ;;
    esac
done

# ------------------------------------------------------------------
# 5. Salida
# ------------------------------------------------------------------
for entry in "${apps[@]}"; do
    name="${entry%%$'\t'*}"
    rest="${entry#*$'\t'}"
    cmd="${rest%%$'\t'*}"
    icon="${rest##*$'\t'}"
    path=""
    if [ -n "$icon" ]; then
        case "$icon" in
            /*) path="$icon" ;;
            *)  path="${icon_of[$icon]:-}" ;;
        esac
    fi
    printf '%s\t%s\t%s\n' "$name" "$cmd" "$path"
done | sort -f -t$'\t' -k1,1
