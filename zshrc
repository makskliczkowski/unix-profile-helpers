# Oh My Zsh is optional. Override ZSH in local.zsh if it is installed elsewhere.
: "${ZSH:=$HOME/.oh-my-zsh}"
export ZSH

# Machine-specific values (including UPH_SAFE=0 to disable common-safety.sh)
# belong here. The deployer creates this file once and preserves it.
UPH_ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
UPH_LOCAL_CONFIG="$UPH_ZSH_CONFIG_DIR/local.zsh"
[[ -r "$UPH_LOCAL_CONFIG" ]] && source "$UPH_LOCAL_CONFIG"

# Oh My Zsh settings (ignored when Oh My Zsh is not installed).
: "${ZSH_THEME:=robbyrussell}"

# History and completion tuning.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' rehash true

# Oh My Zsh plugins bundled with installed commands.
plugins=(git)

command -v docker >/dev/null 2>&1 && plugins+=(docker)
command -v asdf >/dev/null 2>&1 && plugins+=(asdf)
command -v zoxide >/dev/null 2>&1 && plugins+=(zoxide)

# Optional third-party plugins are loaded only when installed.
for UPH_PLUGIN in \
    zsh-autosuggestions \
    zsh-history-substring-search \
    fast-syntax-highlighting
do
    UPH_PLUGIN_DIR="${ZSH_CUSTOM:-$ZSH/custom}/plugins/$UPH_PLUGIN"
    [[ -d "$UPH_PLUGIN_DIR" ]] && plugins+=("$UPH_PLUGIN")
done
unset UPH_PLUGIN UPH_PLUGIN_DIR

# zsh-completions normally extends fpath only after compinit has run. Loading
# its completion directory first keeps Oh My Zsh's dump metadata stable and
# avoids rebuilding hundreds of completions on every shell startup.
UPH_ZSH_COMPLETIONS="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src"
[[ -d "$UPH_ZSH_COMPLETIONS" ]] && fpath=("$UPH_ZSH_COMPLETIONS" $fpath)
unset UPH_ZSH_COMPLETIONS

if (( ${#UPH_EXTRA_PLUGINS[@]} )); then
    for UPH_PLUGIN in "${UPH_EXTRA_PLUGINS[@]}"; do
        if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$UPH_PLUGIN" || -d "$ZSH/plugins/$UPH_PLUGIN" ]]; then
            plugins+=("$UPH_PLUGIN")
        else
            print -u2 "Skipping missing Oh My Zsh plugin: $UPH_PLUGIN"
        fi
    done
fi
unset UPH_PLUGIN

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# History substring search bindings for the plugin above.
if (( ${+functions[history-substring-search-up]} )); then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey '^[OA' history-substring-search-up
    bindkey '^[OB' history-substring-search-down
fi

# anaconda / miniforge lazy loader (prevents slow terminal startup)
conda() {
    local conda_sh

    for conda_sh in \
        "$HOME/miniforge3/etc/profile.d/conda.sh" \
        "$HOME/miniconda3/etc/profile.d/conda.sh" \
        "$HOME/anaconda3/etc/profile.d/conda.sh" \
        "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh"
    do
        if [[ -r "$conda_sh" ]]; then
            unset -f conda
            source "$conda_sh"
            conda "$@"
            return
        fi
    done

    print -u2 "Conda initialization script not found."
    return 127
}

# User-local executables. The unique path array avoids duplicate PATH entries.
typeset -U path PATH

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d /opt/homebrew/bin ]] && path=(/opt/homebrew/bin $path)
[[ -d /opt/homebrew/sbin ]] && path=(/opt/homebrew/sbin $path)

export PATH

# Use a terminal-safe editor over SSH and VS Code locally when available.
if [[ -z ${EDITOR:-} ]]; then
    if [[ -n ${SSH_CONNECTION:-} ]]; then
        command -v nano >/dev/null 2>&1 && EDITOR=nano || EDITOR=vi
    elif command -v code >/dev/null 2>&1; then
        EDITOR='code --wait'
    elif command -v nvim >/dev/null 2>&1; then
        EDITOR=nvim
    elif command -v nano >/dev/null 2>&1; then
        EDITOR=nano
    else
        EDITOR=vi
    fi
fi
export EDITOR
: "${VISUAL:=$EDITOR}"
export VISUAL

# Shared aliases, helpers and safe interactive defaults.
for UPH_FILE in common-safety.sh common-aliases.zsh; do
    [[ -r "$UPH_ZSH_CONFIG_DIR/$UPH_FILE" ]] && source "$UPH_ZSH_CONFIG_DIR/$UPH_FILE"
done
unset UPH_FILE
