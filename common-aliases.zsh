# Portable Zsh aliases and small utilities (Linux and macOS).

alias reloadzsh='exec zsh'
alias cls='clear'
alias path='printf "%s\n" ${path}'
alias mkdirp='mkdir -p'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

if command -v eza >/dev/null 2>&1; then
    alias l='eza -1 --group-directories-first'
    alias ll='eza -lah --group-directories-first --git'
    alias la='eza -la --group-directories-first'
else
    alias l='ls -1'
    alias ll='ls -lah'
    alias la='ls -la'
fi

# Open FILE in $EDITOR (which may carry arguments, e.g. "code --wait").
uph_edit() {
    local -a editor_command
    editor_command=(${(z)${EDITOR:-nano}})
    command "${editor_command[@]}" "$@"
}

# Open FILE with the desktop default application, else in the editor.
open_file() {
    if command -v xdg-open >/dev/null 2>&1; then
        command xdg-open "$1" >/dev/null 2>&1 &!
    elif command -v open >/dev/null 2>&1; then
        command open "$1"
    else
        uph_edit "$1"
    fi
}

mkcd() {
    mkdir -p -- "$1" && cd -- "$1"
}

# rsync wrapper: copy by default (never overwrites existing files), move with --rm.
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
        echo "Error: missing arguments. Use -h for help." >&2
        return 1
    fi

    local src="$1"
    local dst="$2"

    [[ "$src" == "~"* ]] && src="${src/#\~/$HOME}"
    [[ "$dst" == "~"* ]] && dst="${dst/#\~/$HOME}"

    local opts=(-avh --ignore-existing --progress -e "ssh -p $ssh_port")
    local delete_opt=()
    [[ $delete_flag -eq 1 ]] && delete_opt=(--remove-source-files)

    echo -e "\033[1;34mRunning:\033[0m rsync ${opts[*]} ${delete_opt[*]} \"$src\" \"$dst\""
    rsync "${opts[@]}" "${delete_opt[@]}" "$src" "$dst"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        echo -e "\033[1;31mError:\033[0m rsync failed (exit code $rc)" >&2
        return $rc
    fi

    if [[ $delete_flag -eq 1 ]]; then
        if [[ "$src" != *":"* ]]; then
            find "$src" -type d -empty -delete
        else
            ssh -p "$ssh_port" "${src%%:*}" "find \"${src#*:}\" -type d -empty -delete"
        fi
    fi
}

extract() {
    if [[ -z "$1" || ! -f "$1" ]]; then
        echo "Usage: extract <archive>" >&2
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
        *) echo "extract: unsupported archive type: $1" >&2; return 1 ;;
    esac
}
