# Safe interactive defaults for Bash and Zsh. Source from ~/.bashrc or ~/.zshrc;
# the file stands alone. Non-interactive shells are never touched.
#
#   UPH_SAFE=0     disable everything below
#   UPH_UMASK=027  override the private default (077), e.g. for group-shared work
#
# Effects: new files are private to the user; commands typed with a leading
# space stay out of the history (use that for anything containing a secret, or
# read it with `read -rs VAR`); `>` refuses to overwrite a file (`>|` forces);
# cp, mv and rm ask before destroying data.
# shellcheck shell=bash

_uph_safe_init() {
    case $- in *i*) ;; *) return 0 ;; esac

    umask "${UPH_UMASK:-077}"
    set -o noclobber

    if [ -n "${ZSH_VERSION:-}" ]; then
        setopt HIST_IGNORE_SPACE
    else
        case ":${HISTCONTROL:-}:" in
            *:ignorespace:*|*:ignoreboth:*) ;;
            *) HISTCONTROL="${HISTCONTROL:+$HISTCONTROL:}ignorespace" ;;
        esac
        shopt -s histappend
    fi

    alias cp='cp -i'
    alias mv='mv -i'
    # rm -I (one prompt for bulk deletes) is not available everywhere.
    if rm -I -f -- /nonexistent-uph-probe 2>/dev/null; then
        alias rm='rm -I'
    else
        alias rm='rm -i'
    fi
}

if [ "${UPH_SAFE:-1}" != 0 ]; then
    _uph_safe_init
fi
unset -f _uph_safe_init
