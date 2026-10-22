# Declarative HPC profiles shared by the shell helpers and external tools.
# Source from Bash or Zsh. A profile is a shell fragment containing assignments
# only; it must not run commands when sourced.
#
# A profile is the account on a cluster. Optional run presets live beside it as
# <name>.d/<run>.sh, hold only the keys they override, and are selected with
# "<name>:<run>". Lookup: $HPC_PROFILE_DIR/<name>.sh, or an explicit .sh path.
#
# Loading a profile sets HPC_* shell variables and exports only HPC_PROFILE and
# HPC_PROFILE_RUN. hpc_env_apply is the only function that exports anything
# from HPC_ENV_VARS.
# shellcheck shell=bash

HPC_PROFILE_DIR="${HPC_PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hpc/profiles}"

# Single list of schema keys, so switching profiles cannot leak stale values.
_hpc_profile_scalars="
HPC_NAME HPC_DESCRIPTION HPC_SSH_HOST HPC_SSH_USER HPC_SSH_PORT
HPC_SSH_PROXYJUMP HPC_SSH_IDENTITY HPC_SLURM_ACCOUNT HPC_SLURM_PARTITION
HPC_SLURM_QOS HPC_SLURM_TIME HPC_SLURM_MEM HPC_SLURM_CPUS HPC_SLURM_GPUS
HPC_SLURM_GPU_STYLE HPC_SLURM_NODES HPC_SLURM_MAIL HPC_ENV_INIT HPC_ENV_PURGE
HPC_ENV_CONDA HPC_SCRATCH_DIR HPC_QUOTA_GROUP HPC_SHELL HPC_WORKDIR HPC_PYTHON
HPC_JUPYTER_CMD HPC_JUPYTER_IP HPC_JUPYTER_PORT HPC_TERM_BASHRC HPC_NOTES
"
_hpc_profile_arrays="
HPC_SSH_OPTIONS HPC_SLURM_EXTRA HPC_ENV_MODULES HPC_ENV_SOURCE HPC_ENV_VARS
HPC_ENV_PRE HPC_JUPYTER_EXTRA HPC_TERM_SOURCE
"

# Zsh does not split unquoted parameters unless asked; Bash ignores this line.
_hpc_split='[ -z "${ZSH_VERSION:-}" ] || setopt local_options sh_word_split'

hpc_profile_clear() {
    eval "$_hpc_split"
    for _hpc_v in $_hpc_profile_scalars $_hpc_profile_arrays; do
        unset "$_hpc_v"
    done
    unset _hpc_v
}

hpc_profile_path() {
    _hpc_name="${1:-${HPC_PROFILE:-default}}"
    case "$_hpc_name" in
        /*|*/*|*.sh)
            [ -r "$_hpc_name" ] && { printf '%s\n' "$_hpc_name"; return 0; }
            ;;
    esac
    [ -r "$HPC_PROFILE_DIR/$_hpc_name.sh" ] &&
        { printf '%s\n' "$HPC_PROFILE_DIR/$_hpc_name.sh"; return 0; }
    return 1
}

hpc_profile_list() {
    [ -d "$HPC_PROFILE_DIR" ] || return 0
    for _hpc_file in "$HPC_PROFILE_DIR"/*.sh; do
        [ -e "$_hpc_file" ] || continue
        _hpc_base=${_hpc_file##*/}
        printf '%s\n' "${_hpc_base%.sh}"
    done
}

# Fill only the empty fields. Explicit profile values always win.
hpc_profile_defaults() {
    : "${HPC_SLURM_NODES:=1}"
    : "${HPC_SLURM_CPUS:=1}"
    : "${HPC_SLURM_TIME:=08:00:00}"
    : "${HPC_SLURM_GPU_STYLE:=gres}"
    : "${HPC_ENV_PURGE:=true}"
    : "${HPC_PYTHON:=python3}"
    : "${HPC_JUPYTER_CMD:=jupyter lab}"
    : "${HPC_JUPYTER_IP:=0.0.0.0}"
    : "${HPC_JUPYTER_PORT:=0}"
    : "${HPC_TERM_BASHRC:=true}"
    # Arrays need explicit initialization for nounset-safe expansion.
    [ "${HPC_SSH_OPTIONS+x}" ] || HPC_SSH_OPTIONS=()
    [ "${HPC_SLURM_EXTRA+x}" ] || HPC_SLURM_EXTRA=()
    [ "${HPC_ENV_MODULES+x}" ] || HPC_ENV_MODULES=()
    [ "${HPC_ENV_SOURCE+x}" ] || HPC_ENV_SOURCE=()
    [ "${HPC_ENV_VARS+x}" ] || HPC_ENV_VARS=()
    [ "${HPC_ENV_PRE+x}" ] || HPC_ENV_PRE=()
    [ "${HPC_JUPYTER_EXTRA+x}" ] || HPC_JUPYTER_EXTRA=()
    [ "${HPC_TERM_SOURCE+x}" ] || HPC_TERM_SOURCE=()
}

hpc_profile_load() {
    _hpc_ref="${1:-}"
    _hpc_run=""
    case "$_hpc_ref" in
        *:*) _hpc_run=${_hpc_ref#*:}; _hpc_ref=${_hpc_ref%%:*} ;;
    esac
    _hpc_file=$(hpc_profile_path "$_hpc_ref") || {
        printf 'hpc: profile not found: %s\n' "${_hpc_ref:-${HPC_PROFILE:-default}}" >&2
        return 1
    }
    if [ -n "$_hpc_run" ]; then
        _hpc_run_file="${_hpc_file%.sh}.d/$_hpc_run.sh"
        case "$_hpc_run" in
            *[!A-Za-z0-9._-]*) _hpc_run_file="" ;;
        esac
        [ -r "$_hpc_run_file" ] || {
            printf 'hpc: run not found: %s\n' "$_hpc_run" >&2
            return 1
        }
    fi
    hpc_profile_clear
    # Profiles are trusted local files.
    # shellcheck disable=SC1090
    . "$_hpc_file"
    # shellcheck disable=SC1090
    [ -n "$_hpc_run" ] && . "$_hpc_run_file"
    HPC_PROFILE_RUN=$_hpc_run
    HPC_PROFILE="${HPC_NAME:-${_hpc_file##*/}}"
    HPC_PROFILE="${HPC_PROFILE%.sh}"
    HPC_PROFILE_FILE=$_hpc_file
    hpc_profile_defaults
    export HPC_PROFILE HPC_PROFILE_RUN
    unset _hpc_file _hpc_ref _hpc_run _hpc_run_file
    return 0
}

hpc_profile_show() {
    printf 'profile   %s\n' "${HPC_PROFILE:-<none>}"
    [ -n "${HPC_PROFILE_RUN:-}" ] && printf 'run       %s\n' "$HPC_PROFILE_RUN"
    [ -n "${HPC_DESCRIPTION:-}" ] && printf 'about     %s\n' "$HPC_DESCRIPTION"
    printf 'ssh       %s\n' "${HPC_SSH_HOST:-<unset>}"
    printf 'account   %s\n' "${HPC_SLURM_ACCOUNT:-<unset>}"
    printf 'partition %s\n' "${HPC_SLURM_PARTITION:-<unset>}"
    printf 'time      %s\n' "${HPC_SLURM_TIME:-}"
    printf 'cpus      %s\n' "${HPC_SLURM_CPUS:-}"
    [ -n "${HPC_SLURM_GPUS:-}" ] && printf 'gpus      %s\n' "$HPC_SLURM_GPUS"
    printf 'modules   %s\n' "${HPC_ENV_MODULES[*]:-<none>}"
    [ -n "${HPC_ENV_CONDA:-}" ] && printf 'conda     %s\n' "$HPC_ENV_CONDA"
    [ -n "${HPC_SCRATCH_DIR:-}" ] && printf 'scratch   %s\n' "$HPC_SCRATCH_DIR"
    printf 'workdir   %s\n' "${HPC_WORKDIR:-<unset>}"
}

# ---------------------------------------------------------------------------
# Environment: the only place HPC_ENV_* entries take effect.
# ---------------------------------------------------------------------------

# Make `module` available (Environment Modules or Lmod).
hpc_module_init() {
    command -v module >/dev/null 2>&1 && return 0
    if [ -n "${HPC_ENV_INIT:-}" ]; then
        eval "$HPC_ENV_INIT" >/dev/null 2>&1 || true
        command -v module >/dev/null 2>&1 && return 0
    fi
    for _hpc_init in /etc/profile.d/modules.sh /usr/share/Modules/init/bash \
                     /usr/share/lmod/lmod/init/bash; do
        [ -r "$_hpc_init" ] || continue
        # shellcheck disable=SC1090
        . "$_hpc_init"
        command -v module >/dev/null 2>&1 && return 0
    done
    printf 'hpc: Environment Modules/Lmod is unavailable.\n' >&2
    return 1
}

# Print $1 with a leading ~ and $NAME / ${NAME} expanded. Command substitution
# and arithmetic are neutralised, so a profile value cannot run code here.
hpc_expand() {
    _hpc_e=$(printf '%s' "$1" | sed -e 's/[\\"`]/\\&/g' -e 's/\$(/\\$(/g')
    _hpc_e=$(eval "printf '%s' \"$_hpc_e\"" 2>/dev/null) || return 1
    case "$1" in "~"|"~/"*) _hpc_e=$HOME${_hpc_e#\~} ;; esac
    printf '%s' "$_hpc_e"
}

# Apply the active profile's environment to the current shell, in this order:
# HPC_ENV_INIT, module purge, modules, conda, sourced files, variables, and
# HPC_ENV_PRE commands. Stops at the first failing step.
hpc_env_apply() {
    [ -z "${HPC_ENV_INIT:-}" ] || eval "$HPC_ENV_INIT" || return 1

    if [ "${#HPC_ENV_MODULES[@]}" -gt 0 ]; then
        hpc_module_init || return 1
        case "${HPC_ENV_PURGE:-true}" in
            true|1|yes) module purge >/dev/null 2>&1 || true ;;
        esac
        for _hpc_item in "${HPC_ENV_MODULES[@]}"; do
            module load "$_hpc_item" || { printf 'hpc: cannot load module %s\n' "$_hpc_item" >&2; return 1; }
        done
    fi

    if [ -n "${HPC_ENV_CONDA:-}" ]; then
        if ! command -v conda >/dev/null 2>&1; then
            for _hpc_item in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3"; do
                # shellcheck disable=SC1091
                [ -r "$_hpc_item/etc/profile.d/conda.sh" ] && . "$_hpc_item/etc/profile.d/conda.sh" && break
            done
        fi
        command -v conda >/dev/null 2>&1 || { printf 'hpc: conda not found\n' >&2; return 1; }
        eval "$(conda shell."${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}" hook)" &&
            conda activate "$HPC_ENV_CONDA" || return 1
    fi

    for _hpc_item in ${HPC_ENV_SOURCE[@]+"${HPC_ENV_SOURCE[@]}"}; do
        _hpc_value=$(hpc_expand "$_hpc_item") || return 1
        # shellcheck disable=SC1090
        . "$_hpc_value" || { printf 'hpc: cannot source %s\n' "$_hpc_value" >&2; return 1; }
    done

    for _hpc_item in ${HPC_ENV_VARS[@]+"${HPC_ENV_VARS[@]}"}; do
        case "$_hpc_item" in
            [A-Za-z_]*=*) ;;
            *) printf 'hpc: ignoring HPC_ENV_VARS entry (need KEY=VALUE): %s\n' "$_hpc_item" >&2; continue ;;
        esac
        _hpc_value=$(hpc_expand "${_hpc_item#*=}") || { printf 'hpc: cannot expand %s\n' "$_hpc_item" >&2; return 1; }
        export "${_hpc_item%%=*}=$_hpc_value"
    done

    for _hpc_item in ${HPC_ENV_PRE[@]+"${HPC_ENV_PRE[@]}"}; do
        eval "$_hpc_item" || return 1
    done
    unset _hpc_item _hpc_value _hpc_init
}

if [ "${HPC_PROFILE_AUTOLOAD:-1}" = 1 ]; then
    if [ -n "${HPC_PROFILE:-}" ]; then
        hpc_profile_load "$HPC_PROFILE${HPC_PROFILE_RUN:+:$HPC_PROFILE_RUN}" || true
    elif [ -r "$HPC_PROFILE_DIR/default.sh" ]; then
        hpc_profile_load default || true
    fi
fi
