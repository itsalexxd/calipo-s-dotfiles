# ==========================================
# Prompt de oh-my-posh (tema a medida: alexg.omp.json)
# ==========================================
if command -v oh-my-posh >/dev/null 2>&1; then
    export POSH_THEME="$HOME/.config/oh-my-posh/alexg.omp.json"
    export POSH_SHELL="zsh"

    # Caché para que el prompt arranque rápido (se regenera sola al cambiar el tema)
    export POSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-posh"

    eval "$(oh-my-posh init zsh --config "$POSH_THEME")"
fi

# ==========================================
# zsh-syntax-highlighting + autosuggestions
# ==========================================
# Sintaxis coloreada mientras escribes
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Sugerencias en gris basadas en el historial (acepta con Ctrl+Espacio o flecha derecha)
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#75715e"
    bindkey '^ ' autosuggest-accept
fi
