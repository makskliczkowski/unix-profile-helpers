# Common aliases and helpers intended to be portable across machines.

alias reloadzsh='exec zsh'
alias cls='clear'
alias path='printf "%s\n" ${path}'
alias mkdirp='mkdir -p'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias zshconfig='mate ~/.zshrc'
alias ohmyzsh='mate ~/.oh-my-zsh'
alias mkobsidian='cd "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes"'
alias mkcontext='mate ~/.config/zsh/common-aliases.zsh'
alias codes='cd ~/Codes'
alias pyqusolver='cd ~/Codes/QuantumEigenSolver/pyqusolver'
alias qesgen='cd ~/Codes/QuantumEigenSolver/pyqusolver/Python/QES/general_python'

if command -v eza >/dev/null 2>&1; then
    alias l='eza -1 --group-directories-first'
    alias ll='eza -lah --group-directories-first --git'
    alias la='eza -la --group-directories-first'
else
    alias l='ls -1'
    alias ll='ls -lah'
    alias la='ls -la'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

mkcd() {
    mkdir -p -- "$1" && cd -- "$1"
}

# Unified rsync wrapper: copy by default, move with --rm.
rscp() {
    local delete_flag=0
    local ssh_port=22

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --rm) delete_flag=1; shift ;;
            -p|-P) ssh_port="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: rscp [--rm] [-p PORT] <src> <dst>"
                echo "  --rm        remove source files after successful transfer"
                echo "  -p, -P PORT specify SSH port (default: 22)"
                return 0
                ;;
            *) break ;;
        esac
    done

    if [[ $# -lt 2 ]]; then
        echo "Error: missing arguments. Use -h for help."
        return 1
    fi

    local src="$1"
    local dst="$2"

    [[ "$src" == "~"* ]] && src="${src/#\~/$HOME}"
    [[ "$dst" == "~"* ]] && dst="${dst/#\~/$HOME}"

    local opts=(
        -avh
        --ignore-existing
        --progress
        -e "ssh -p $ssh_port"
    )

    local delete_opt=()
    [[ $delete_flag -eq 1 ]] && delete_opt=(--remove-source-files)

    echo -e "\033[1;34mRunning:\033[0m rsync ${opts[*]} ${delete_opt[*]} \"$src\" \"$dst\""
    rsync "${opts[@]}" "${delete_opt[@]}" "$src" "$dst"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        echo -e "\033[1;31mError:\033[0m rsync failed (exit code $rc)"
        return $rc
    fi

    if [[ $delete_flag -eq 1 ]]; then
        echo -e "\033[1;33mCleaning empty directories...\033[0m"
        if [[ "$src" != *":"* ]]; then
            find "$src" -type d -empty -delete
        else
            local host="${src%%:*}"
            local path="${src#*:}"
            ssh -p "$ssh_port" "$host" "find \"$path\" -type d -empty -delete"
        fi
    fi
}

extract() {
    if [[ -z "$1" || ! -f "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar xjf "$1" ;;
        *.tar.gz|*.tgz) tar xzf "$1" ;;
        *.tar.xz|*.txz) tar xJf "$1" ;;
        *.tar) tar xf "$1" ;;
        *.bz2) bunzip2 "$1" ;;
        *.gz) gunzip "$1" ;;
        *.xz) unxz "$1" ;;
        *.zip) unzip "$1" ;;
        *.7z) 7z x "$1" ;;
        *.rar) unrar x "$1" ;;
        *) echo "extract: unsupported archive type: $1"; return 1 ;;
    esac
}

mkhelp() {
    local mode="${1:-summary}"
    local custom_source="$HOME/.config/zsh/common-aliases.zsh"
    local vault_source="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes/common-aliases.zsh"
    local name
    local -a alias_names function_names custom_alias_names custom_function_names other_aliases other_functions
    typeset -A custom_alias_desc custom_function_desc

    custom_alias_names=(
        reloadzsh cls path mkdirp .. ... .... zshconfig ohmyzsh mkobsidian mkcontext codes pyqusolver qesgen
        l ll la cat grep condastat juliastat
    )
    custom_function_names=(mkcd rscp extract mkhelp armacmp obsearch obnew)

    custom_alias_desc=(
        reloadzsh "reload the current zsh session"
        cls "clear the terminal"
        path "print PATH entries one per line"
        mkdirp "mkdir -p shorthand"
        .. "go up one directory"
        ... "go up two directories"
        .... "go up three directories"
        zshconfig "open ~/.zshrc"
        ohmyzsh "open ~/.oh-my-zsh"
        mkobsidian "jump to the Obsidian vault"
        mkcontext "open the shared shell context file"
        codes "jump to ~/Codes"
        pyqusolver "jump to ~/Codes/QuantumEigenSolver/pyqusolver"
        qesgen "jump to QuantumEigenSolver/pyqusolver/Python/QES/general_python"
        l "short directory listing"
        ll "long directory listing"
        la "show hidden files too"
        cat "use bat when available"
        grep "use ripgrep when available"
        condastat "print current active conda env status"
        juliastat "print current active julia version status"
    )
    custom_function_desc=(
        mkcd "create a directory and enter it"
        rscp "rsync wrapper with optional --rm cleanup"
        extract "extract common archive formats"
        mkhelp "show this command reference"
        armacmp "compile C++ script with Armadillo linked"
        obsearch "search through Obsidian notes with ripgrep"
        obnew "create a new scientific note in Obsidian vault"
    )

    alias_names=(${(ok)aliases})
    function_names=(${(ok)functions})
    function_names=(${function_names:#_OMZ*})
    function_names=(${function_names:#_*})
    function_names=(${function_names:#precmd})
    function_names=(${function_names:#preexec})
    function_names=(${function_names:#zshexit})
    function_names=(${function_names:#chpwd})

    other_aliases=($alias_names)
    for name in $custom_alias_names; do
        other_aliases=(${other_aliases:#$name})
    done

    other_functions=($function_names)
    for name in $custom_function_names; do
        other_functions=(${other_functions:#$name})
    done

    print "=============================="
    print "mkhelp: shell command reference"
    print "=============================="
    print ""
    print "Config files"
    print "  active: $custom_source"
    print "  vault : $vault_source"
    print ""
    print "Custom aliases"
    for name in $custom_alias_names; do
        [[ -n ${aliases[$name]-} ]] || continue
        printf '  %-10s  %-38s %s\n' "$name" "${custom_alias_desc[$name]}" "-> ${aliases[$name]}"
    done
    print ""
    print "Custom functions"
    for name in $custom_function_names; do
        (( ${+functions[$name]} )) || continue
        printf '  %-10s  %s\n' "$name" "${custom_function_desc[$name]}"
    done
    print ""
    print "Active plugins"
    print "  ${plugins[*]}"
    print ""
    printf 'Loaded totals: %d aliases, %d functions\n' "${#alias_names}" "${#function_names}"
    printf 'Custom totals: %d aliases, %d functions\n' "${#custom_alias_names}" "${#custom_function_names}"

    if [[ "$mode" != "all" ]]; then
        print ""
        print "Run 'mkhelp all' for the full live-shell alias/function inventory."
        return 0
    fi

    print ""
    print "Other aliases from oh-my-zsh/plugins/current shell"
    for name in $other_aliases; do
        printf '  %-18s %s\n' "$name" "${aliases[$name]}"
    done

    print ""
    print "Other functions from oh-my-zsh/plugins/current shell"
    for name in $other_functions; do
        printf '  %s\n' "$name"
    done
}

# ==========================================
# 🚀 Scientific Development & Language Helpers
# ==========================================

# Active Python/Conda environment status
alias condastat="echo -e \"Conda Env: \033[1;32m\${CONDA_DEFAULT_ENV:-none}\033[0m (Python: \$(python --version 2>&1 | awk '{print \$2}'))\""

# Active Julia environment status
alias juliastat="echo -e \"Julia: \033[1;34m\$(julia --version 2>&1 | awk '{print \$3}')\033[0m\""

# Armadillo C++ Compiler Helper
# Compiles a C++ script with optimized flags (-O3) and links Armadillo
armacmp() {
    if [[ -z "$1" ]]; then
        echo "Usage: armacmp <source_file.cpp>"
        return 1
    fi
    local src="$1"
    local out="${src%.cpp}.out"
    local -a include_flags=()

    if [[ -n "$ARMADILLO_INCL_DIR" ]]; then
        if [[ ! -d "$ARMADILLO_INCL_DIR" ]]; then
            echo "Configured Armadillo include directory does not exist: $ARMADILLO_INCL_DIR"
            return 1
        fi
        include_flags=(-I "$ARMADILLO_INCL_DIR")
    fi

    echo -e "\033[1;34mCompiling:\033[0m g++ -O3 -std=c++17 ${include_flags[*]} \"$src\" -o \"$out\" -larmadillo"
    g++ -O3 -std=c++17 "${include_flags[@]}" "$src" -o "$out" -larmadillo
    
    if [[ $? -eq 0 ]]; then
        echo -e "\033[1;32mCompilation successful!\033[0m Executable: ./$out"
    fi
}

# ==========================================
# 📓 Obsidian vault integration
# ==========================================

# Search your physics and scientific notes vault using ripgrep
obsearch() {
    if [[ -z "$1" ]]; then
        echo "Usage: obsearch <query>"
        return 1
    fi
    local vault_dir="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes"
    if [[ -d "$vault_dir" ]]; then
        rg -i --heading --color=always "$1" "$vault_dir"
    else
        echo "Obsidian vault path not found."
        return 1
    fi
}

# Create a new markdown note in your vault with a scientific metadata template
obnew() {
    if [[ -z "$1" ]]; then
        echo "Usage: obnew <note-title>"
        return 1
    fi
    local vault_dir="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes"
    if [[ ! -d "$vault_dir" ]]; then
        echo "Obsidian vault path not found."
        return 1
    fi
    
    local title="$1"
    # Convert title to a safe filename (lower case, hyphens)
    local filename=$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]').md
    local filepath="$vault_dir/$filename"
    
    if [[ -f "$filepath" ]]; then
        echo "Note '$filename' already exists."
        return 1
    fi
    
    # Write YAML frontmatter
    cat <<EOF > "$filepath"
---
title: "$title"
date: $(date +"%Y-%m-%d %H:%M:%S")
tags: [physics, research]
---

# $title

## Abstract


## Discussion

EOF

    echo "Created note: $filepath"
    # Open the note immediately
    if command -v mate >/dev/null 2>&1; then
        mate "$filepath"
    else
        open "$filepath"
    fi
}

# ==========================================
# 🎛️ Load HPC/Slurm-specific local controls
# ==========================================
if [[ -f "$HOME/.config/zsh/common-hpc.zsh" ]]; then
    source "$HOME/.config/zsh/common-hpc.zsh"
fi
