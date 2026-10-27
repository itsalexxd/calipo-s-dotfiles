#!/usr/bin/env bash
# Instalador de dotfiles - AlexG
# Hyprland + Quickshell + Wayland

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
DO_PKGS=1
DO_GREETD=0
DO_ZSH=1

for arg in "$@"; do
  case "$arg" in
  --no-pkgs) DO_PKGS=0 ;;
  --greetd)   DO_GREETD=1 ;;
  --no-zsh)   DO_ZSH=0 ;;
  -h|--help)
    grep '^#' "$0" | head -n 25 | sed 's/^# \?//'
    exit 0
    ;;
  *)
    echo "Opción desconocida: $arg"
    echo "Usa --help para ver las opciones"
    exit 1
    ;;
  esac
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m!!\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }

# ---------- Paquetes ----------
PKGS_OFFICIAL=(
  hyprland hypridle
  quickshell
  kitty
  yazi
  fuzzel
  waypaper
  awww
  wl-clipboard
  cliphist
  brightnessctl
  playerctl
  wireplumber pipewire pipewire-pulse pavucontrol
  networkmanager nm-connection-editor
  iwd
  bluez blueman
  jq iw
  btop fastfetch
  ripgrep fd
  git curl wget unzip zip
  wlroots wayland-protocols
  qt5ct qt6ct
  polkit-gnome
  xdg-utils xdg-desktop-portal xdg-desktop-portal-hyprland
  fontconfig
  inter-font ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
  thunar tumbler ffmpegthumbnailer gvfs
  greetd cage
)

PKGS_AUR=(
  pywal
  hyprshot
  wlsunset
  wl-color-picker
)

# ---------- Funciones ----------
link() {
  local src="$1" dst="$2"
  [ -e "$src" ] || { warn "No existe $src, se omite"; return 0; }
  mkdir -p "$(dirname "$dst")"
  # Si ya apunta al mismo sitio
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    ok "$dst ya enlazado correctamente"
    return 0
  fi
  # Backup si existe y no es symlink correcto
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"
    local bname
    bname="$(echo "$dst" | sed "s|$HOME/||" | tr '/' '_')"
    mv "$dst" "$BACKUP/$bname"
    warn "Backup creado: $BACKUP/$bname"
  fi
  ln -sf "$src" "$dst"
  ok "$dst -> $src"
}

# ---------- Instalación de paquetes ----------
if [ "$DO_PKGS" -eq 1 ]; then
  log "Instalando paquetes oficiales (pacman)"
  sudo pacman -S --needed --noconfirm "${PKGS_OFFICIAL[@]}" || warn "Algunos paquetes oficiales han fallado. Revisa la salida."

  if command -v yay >/dev/null 2>&1; then
    log "Instalando paquetes AUR con yay"
    yay -S --needed --noconfirm "${PKGS_AUR[@]}" || warn "Algunos paquetes AUR han fallado."
  elif command -v paru >/dev/null 2>&1; then
    log "Instalando paquetes AUR con paru"
    paru -S --needed --noconfirm "${PKGS_AUR[@]}" || warn "Algunos paquetes AUR han fallado."
  else
    warn "No se encontró yay ni paru."
    warn "Instala manualmente los paquetes AUR: ${PKGS_AUR[*]}"
  fi
else
  log "Omitiendo instalación de paquetes (--no-pkgs)"
fi

# ---------- Enlaces simbólicos de configuración ----------
log "Creando enlaces simbólicos de configuración"

# Hyprland
link "$DOTFILES/config/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
[ -f "$DOTFILES/config/hypr/refresg.sh" ] && link "$DOTFILES/config/hypr/refresg.sh" "$HOME/.config/hypr/refresg.sh" && chmod +x "$HOME/.config/hypr/refresg.sh" 2>/dev/null || true
[ -f "$DOTFILES/config/hypr/update_borders.sh" ] && link "$DOTFILES/config/hypr/update_borders.sh" "$HOME/.config/hypr/update_borders.sh" && chmod +x "$HOME/.config/hypr/update_borders.sh" 2>/dev/null || true
[ -f "$DOTFILES/config/hypr/update_gtk_theme.sh" ] && link "$DOTFILES/config/hypr/update_gtk_theme.sh" "$HOME/.config/hypr/update_gtk_theme.sh" && chmod +x "$HOME/.config/hypr/update_gtk_theme.sh" 2>/dev/null || true
[ -f "$DOTFILES/config/hypr/igpu" ] && link "$DOTFILES/config/hypr/igpu" "$HOME/.config/hypr/igpu" 2>/dev/null || true

# Quickshell
link "$DOTFILES/config/quickshell/shell.qml" "$HOME/.config/quickshell/shell.qml"
link "$DOTFILES/config/quickshell/lock/shell.qml" "$HOME/.config/quickshell/lock/shell.qml"
# Enlazar resto de configuración de quickshell si existe
if [ -d "$DOTFILES/config/quickshell" ]; then
  mkdir -p "$HOME/.config/quickshell"
  for item in "$DOTFILES/config/quickshell"/*; do
    [ -e "$item" ] || continue
    base="$(basename "$item")"
    [ "$base" = "shell.qml" ] && continue
    [ "$base" = "lock" ] && continue
    link "$item" "$HOME/.config/quickshell/$base"
  done
  # Subdirectorios importantes
  for sub in clipboard launcher wallpaper scripts; do
    [ -d "$DOTFILES/config/quickshell/$sub" ] && link "$DOTFILES/config/quickshell/$sub" "$HOME/.config/quickshell/$sub"
  done
fi

# Greeter (para uso opcional)
[ -f "$DOTFILES/config/greeter/shell.qml" ] && link "$DOTFILES/config/greeter/shell.qml" "$HOME/.config/greeter/shell.qml"

# Fontconfig
[ -f "$DOTFILES/config/fontconfig/fonts.conf" ] && link "$DOTFILES/config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"

# Waypaper
[ -f "$DOTFILES/config/waypaper/config.ini" ] && link "$DOTFILES/config/waypaper/config.ini" "$HOME/.config/waypaper/config.ini"

# Zsh
if [ "$DO_ZSH" -eq 1 ]; then
  mkdir -p "$HOME/.config/zsh"
  [ -f "$DOTFILES/config/zsh/prompt.zsh" ] && link "$DOTFILES/config/zsh/prompt.zsh" "$HOME/.config/zsh/prompt.zsh"
fi

# Fastfetch
[ -f "$DOTFILES/config/fastfetch/config.jsonc" ] && link "$DOTFILES/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

# ---------- Scripts locales ----------
log "Instalando scripts en ~/.local/bin"
mkdir -p "$HOME/.local/bin"
for s in "$DOTFILES/local/bin"/*; do
  [ -e "$s" ] || continue
  bn="$(basename "$s")"
  link "$s" "$HOME/.local/bin/$bn"
  chmod +x "$HOME/.local/bin/$bn" 2>/dev/null || true
done

# ---------- Wallpapers ----------
log "Enlazando wallpapers"
if [ -d "$DOTFILES/wallpapers" ] && [ "$(ls -A "$DOTFILES/wallpapers" 2>/dev/null)" ]; then
  mkdir -p "$HOME/02_Imagenes"
  link "$DOTFILES/wallpapers" "$HOME/02_Imagenes/Wallpapers"
  ok "Wallpapers enlazados a ~/02_Imagenes/Wallpapers"
fi

# ---------- PATH en .zshrc ----------
log "Configurando entorno"
if ! grep -qs '\.local/bin' "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  ok "Añadido ~/.local/bin al PATH en ~/.zshrc"
fi

# Fuente de prompt.zsh si no está
if [ "$DO_ZSH" -eq 1 ] && [ -f "$HOME/.config/zsh/prompt.zsh" ]; then
  if ! grep -qs 'config/zsh/prompt.zsh' "$HOME/.zshrc" 2>/dev/null; then
    echo '[ -f "$HOME/.config/zsh/prompt.zsh" ] && source "$HOME/.config/zsh/prompt.zsh"' >> "$HOME/.zshrc"
    ok "Añadido source de prompt.zsh a ~/.zshrc"
  fi
fi

# ---------- Fuentes ----------
if command -v fc-cache >/dev/null 2>&1; then
  log "Actualizando cache de fuentes"
  fc-cache -fv >/dev/null 2>&1 && ok "Cache de fuentes actualizado"
fi

# ---------- Greetd (opcional) ----------
if [ "$DO_GREETD" -eq 1 ]; then
  warn "Vas a cambiar de display manager a greetd + Quickshell."
  warn "Asegúrate de tener acceso a una TTY (Ctrl+Alt+F2/F3) por si algo falla."
  read -r -p "¿Deseas continuar? [s/N]: " ans
  if [ "${ans,,}" = "s" ]; then
    log "Configurando greetd"
    sudo mkdir -p /etc/greetd/quickshell
    [ -f /etc/greetd/config.toml ] && sudo cp -n /etc/greetd/config.toml /etc/greetd/config.toml.bak

    sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "env QT_WAYLAND_DISABLE_WINDOWDECORATION=1 cage -s -- qs -p /etc/greetd/quickshell/shell.qml"
user = "greeter"
EOF

    [ -f "$DOTFILES/config/greeter/shell.qml" ] && sudo install -m 644 "$DOTFILES/config/greeter/shell.qml" /etc/greetd/quickshell/shell.qml
    WP="$(find "$DOTFILES/wallpapers" -type f | head -n1 || true)"
    [ -n "$WP" ] && sudo install -m 644 "$WP" /etc/greetd/quickshell/wallpaper

    sudo systemctl disable sddm lightdm gdm 2>/dev/null || true
    sudo systemctl enable greetd
    ok "greetd habilitado. Se aplicará tras reiniciar."
    warn "Si falla el login: desde TTY ejecuta 'sudo systemctl disable greetd && sudo systemctl enable <tu-dm>' y reinicia"
  else
    warn "Configuración de greetd cancelada"
  fi
fi

# ---------- Final ----------
echo
log "Instalación completada"
echo "  Backups (si hubo): $BACKUP"
echo "  Dotfiles: $DOTFILES"
echo
echo "Siguientes pasos:"
echo "  1. Revisa ~/.zshrc si quieres ajustar algo"
echo "  2. Abre Hyprland (o reinicia sesión)"
echo "  3. Si usas pywal, ejecuta 'wal -i <imagen>' para generar tema"
echo
ok "Todo listo!"
