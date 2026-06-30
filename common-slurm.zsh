# Portable Slurm and HPC cluster shell helpers.
# Source from Bash or Zsh, for example from ~/.bashrc or ~/.zshrc.
# shellcheck shell=bash

# Optional per-cluster overrides:
#   UPH_SLURM_PARTITION=normal
#   UPH_SLURM_ACCOUNT=my-project
#   UPH_SLURM_QOS=normal
#   UPH_SLURM_CPUS=4
#   UPH_SLURM_TIME=01:00:00
#   UPH_SLURM_MEMORY=4G
#   UPH_SLURM_GRES=gpu:1
#   UPH_INTERACTIVE_SHELL=/bin/bash
#   UPH_QUOTA_GROUP=my-project
#   UPH_SCRATCH_DIR=/path/to/project/scratch
#   UPH_MODULE_SLURM=slurm
#   UPH_MODULE_COMPILER="compiler-module"
#   UPH_MODULE_MPI="mpi-module"
#   UPH_MODULE_HDF5="hdf5-module"
#   UPH_MODULE_PYTHON="python-module"
#   UPH_MODULE_JULIA="julia-module"
#   UPH_MODULE_CMAKE="cmake-module"
#   UPH_MODULE_CONTAINER="Apptainer"
#   UPH_MODULE_BLAS="blas-module"
#   UPH_MODULE_BOOST="boost-module"
#   UPH_MODULE_NETCDF="netcdf-module"

if [ -r "$HOME/.config/hpc/local.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/local.sh"
fi

if [ -r "$HOME/.config/hpc/common-run.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/common-run.sh"
fi

_uph_info() {
    printf '\033[1;34m%s\033[0m\n' "$*"
}

_uph_success() {
    printf '\033[1;32m%s\033[0m\n' "$*"
}

_uph_warn() {
    printf '\033[1;33m%s\033[0m\n' "$*" >&2
}

_uph_error() {
    printf '\033[1;31m%s\033[0m\n' "$*" >&2
}

_uph_require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        _uph_error "Required command not found: $1"
        return 1
    fi
}

_uph_module_key() {
    case "$1" in
        compiler|cpp|cxx|fortran) printf '%s\n' "COMPILER" ;;
        container|apptainer|singularity) printf '%s\n' "CONTAINER" ;;
        blas|lapack|math) printf '%s\n' "BLAS" ;;
        *)
            printf '%s' "$1" |
                tr '[:lower:]-' '[:upper:]_' |
                tr -cd '[:alnum:]_'
            printf '\n'
            ;;
    esac
}

_uph_module_var() {
    printf 'UPH_MODULE_%s\n' "$(_uph_module_key "$1")"
}

_uph_module_get() {
    local variable
    local value
    variable=$(_uph_module_var "$1")
    eval "value=\${$variable-}"
    printf '%s\n' "$value"
}

_uph_slurm_init() {
    local candidate
    local configured

    command -v srun >/dev/null 2>&1 && return 0
    _uph_module_init >/dev/null 2>&1 || true
    configured=$(_uph_module_get slurm)

    if command -v module >/dev/null 2>&1; then
        for candidate in "$configured" slurm; do
            [ -n "$candidate" ] || continue
            if module load "$candidate" >/dev/null 2>&1 &&
                command -v srun >/dev/null 2>&1; then
                _uph_success "Loaded Slurm client module: $candidate"
                return 0
            fi
        done
    fi

    _uph_error "Slurm client command 'srun' is unavailable."
    echo "Try: module load slurm" >&2
    echo "Then inspect: module list; command -v srun" >&2
    echo "If the module has another name, set UPH_MODULE_SLURM in ~/.config/hpc/local.sh." >&2
    return 1
}

# ==========================================
# Slurm queue and job monitoring
# ==========================================

alias sq='squeue -u "$USER" --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'
alias sqr='squeue -u "$USER" -t running --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'
alias sqn='squeue -u "$USER" -h -t pending,running -r | wc -l'
alias sqnr='squeue -u "$USER" -h -t running -r | wc -l'
alias sac='sacct --starttime=midnight --format=JobID,jobname,partition,ncpus,nodelist,nnodes,AveCPU,totalcpu,MaxRSS,ReqMem,AveRSS,AveVMSize,start,elapsed,state,exitcode'
alias sqall="squeue --format='%.8i %.9P %.18j %.8u %.2t %.10M %.6D %R'"
alias sque='squeue'
alias sqh='squeue -h'
alias sprio_me='sprio -u "$USER"'
alias sqpd='squeue -u "$USER" -t PD -o "%.8i %.9P %.18j %.2t %R"'
alias jobnodes='squeue -u "$USER" -o "%i %R" | grep -v NODELIST'
alias sinfo_avail="sinfo -s -p --format='%.10P %.5a %.10l %.16F'"
alias scanc='scancel'
alias scancall='scancel -u "$USER"'

sqc() {
    squeue -u "$USER" --format='%.8i %.9P %.18j %.8u %.2t %.10M %.6D %R' |
        awk '
            NR == 1 { print; next }
            $5 == "R"  { print "\033[1;32m" $0 "\033[0m"; next }
            $5 == "PD" { print "\033[1;33m" $0 "\033[0m"; next }
            $5 == "CG" { print "\033[1;31m" $0 "\033[0m"; next }
            { print }
        '
}

jobeff() {
    if [ -z "${1:-}" ]; then
        echo "Usage: jobeff <job_id>"
        return 1
    fi
    if command -v seff >/dev/null 2>&1; then
        seff "$1"
    else
        _uph_require_command sacct || return 1
        sacct -j "$1" --format=JobID,JobName,Partition,MaxRSS,Elapsed,State,ExitCode
    fi
}

jobtop() {
    if [ -z "${1:-}" ]; then
        echo "Usage: jobtop <job_id>"
        return 1
    fi
    _uph_slurm_init || return 1
    if command -v htop >/dev/null 2>&1; then
        srun --jobid="$1" --pty htop
    else
        _uph_warn "htop is unavailable; starting top instead."
        srun --jobid="$1" --pty top
    fi
}

# ==========================================
# Interactive jobs and job control
# ==========================================

# Request an interactive Slurm shell with generic scheduling defaults.
sub-interactive() {
    local cores="${UPH_SLURM_CPUS:-1}"
    local walltime="${UPH_SLURM_TIME:-01:00:00}"
    local memory="${UPH_SLURM_MEMORY:-1G}"
    local partition="${UPH_SLURM_PARTITION:-}"
    local account="${UPH_SLURM_ACCOUNT:-${SLURM_ACCOUNT:-${SBATCH_ACCOUNT:-}}}"
    local qos="${UPH_SLURM_QOS:-}"
    local gpu_request="${UPH_SLURM_GRES:-}"
    local shell_path="${UPH_INTERACTIVE_SHELL:-${SHELL:-/bin/bash}}"
    local opt
    local -a options

    OPTIND=1
    while getopts ":c:t:m:p:A:q:g:s:h" opt; do
        case "$opt" in
            c) cores="$OPTARG" ;;
            t) walltime="$OPTARG" ;;
            m) memory="$OPTARG" ;;
            p) partition="$OPTARG" ;;
            A) account="$OPTARG" ;;
            q) qos="$OPTARG" ;;
            g) gpu_request="$OPTARG" ;;
            s) shell_path="$OPTARG" ;;
            h)
                cat <<'EOF'
Usage: sub-interactive [-c cpus] [-t time] [-m memory] [-p partition]
                       [-A account] [-q qos] [-g gpu-request] [-s shell]

Defaults can be set with UPH_SLURM_CPUS, UPH_SLURM_TIME,
UPH_SLURM_MEMORY, UPH_SLURM_PARTITION, UPH_SLURM_ACCOUNT,
UPH_SLURM_QOS, UPH_SLURM_GRES, and UPH_INTERACTIVE_SHELL.

GPU examples:
  -g 1          -> --gres=gpu:1
  -g a100:2     -> --gres=gpu:a100:2
EOF
                return 0
                ;;
            :) _uph_error "Option -$OPTARG requires a value."; return 2 ;;
            \?) _uph_error "Unknown option: -$OPTARG"; return 2 ;;
        esac
    done
    shift $((OPTIND - 1))

    _uph_slurm_init || return 1
    case "$memory" in
        none|default) memory="" ;;
        *[!0-9]*) ;;
        *) memory="${memory}G" ;;
    esac
    if [ ! -x "$shell_path" ]; then
        shell_path=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null)
    fi

    options=(--nodes=1 --ntasks=1 --cpus-per-task="$cores" --time="$walltime")
    [ -n "$memory" ] && options+=(--mem="$memory")
    [ -n "$partition" ] && options+=(--partition="$partition")
    [ -n "$account" ] && options+=(--account="$account")
    [ -n "$qos" ] && options+=(--qos="$qos")
    if [ -n "$gpu_request" ]; then
        case "$gpu_request" in
            gpu:*) options+=(--gres="$gpu_request") ;;
            *) options+=(--gres="gpu:$gpu_request") ;;
        esac
    fi

    _uph_info "Requesting interactive job: srun ${options[*]} --pty $shell_path -l"
    srun "${options[@]}" --pty "$shell_path" -l
}

inter() {
    sub-interactive "$@"
}

salloc_quick() {
    local cores="${1:-${UPH_SLURM_CPUS:-4}}"
    local walltime="${2:-${UPH_SLURM_TIME:-02:00:00}}"
    local partition="${3:-${UPH_SLURM_PARTITION:-}}"
    local -a options

    _uph_require_command salloc || return 1
    options=(--nodes=1 --ntasks=1 --cpus-per-task="$cores" --time="$walltime")
    [ -n "$partition" ] && options+=(--partition="$partition")
    [ -n "${UPH_SLURM_ACCOUNT:-}" ] && options+=(--account="$UPH_SLURM_ACCOUNT")
    [ -n "${UPH_SLURM_QOS:-}" ] && options+=(--qos="$UPH_SLURM_QOS")

    _uph_info "Requesting allocation: salloc ${options[*]}"
    salloc "${options[@]}"
}

# Generate a minimal generic Slurm script without automatic module changes.
mkslurm() {
    if [ -z "${1:-}" ]; then
        echo "Usage: mkslurm <script_name.sh>"
        return 1
    fi
    local out_file="$1"
    case "$out_file" in
        *.sh) ;;
        *) out_file="${out_file}.sh" ;;
    esac
    if [ -e "$out_file" ]; then
        _uph_error "File already exists: $out_file"
        return 1
    fi

    cat <<'EOF' > "$out_file"
#!/bin/bash
#SBATCH --job-name=scientific-job
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=12:00:00
#SBATCH --mem=16G

set -euo pipefail

if [ -f "$HOME/.config/hpc/common-slurm.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/common-slurm.sh"
fi

echo "Job started on $(date) on ${SLURM_NODELIST:-unknown node}"

# Optional modules:
# modload cpp mpi hdf5 python

# Replace with workload:
# srun --ntasks=1 --cpus-per-task="${SLURM_CPUS_PER_TASK:-1}" ./solver
# srun python solver.py

echo "Job finished on $(date)"
EOF
    chmod +x "$out_file"
    _uph_success "Created Slurm submission template: $out_file"
}

# Generate a Cockpit-compatible Slurm script using common-run.sh status files.
mkslurm_cockpit() {
    if [ -z "${1:-}" ]; then
        echo "Usage: mkslurm_cockpit <file.sh>"
        return 1
    fi
    local out_file="$1"
    case "$out_file" in
        *.sh) ;;
        *) out_file="${out_file}.sh" ;;
    esac
    if [ -e "$out_file" ]; then
        _uph_error "File already exists: $out_file"
        return 1
    fi

    cat <<'EOF' > "$out_file"
#!/bin/bash
#SBATCH --job-name=cockpit-job
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=12:00:00
#SBATCH --mem=16G

# COCKPIT_BEGIN
# outputs:
#   stdout: logs/stdout.log
#   stderr: logs/stderr.log
#   result_json: result.json
#   status_json: status.json
#   hdf5_glob:
#     - "output/*.h5"
#     - "output/*.hdf5"
# COCKPIT_END

set -euo pipefail

if [ -f "$HOME/.config/hpc/common-slurm.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/common-slurm.sh"
fi
if [ -f "$HOME/.config/hpc/common-run.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/common-run.sh"
fi

uph_make_run_dir "${SLURM_JOB_NAME:-cockpit-job}" || exit 1
uph_write_manifest "$0" "$@"
uph_write_git_manifest "$PWD" "$RUN_DIR/git.txt"
uph_json_status running

cd "$RUN_DIR"

set +e
(
    set -e
    echo "Job started on $(date) on ${SLURM_NODELIST:-unknown node}"

    # Replace this block with the real workload. Write HDF5 or other data
    # products under "$OUTPUT_DIR" so Cockpit can discover them.
    # srun --ntasks=1 --cpus-per-task="${SLURM_CPUS_PER_TASK:-1}" ./solver
    # srun python solver.py

    # Placeholder result JSON. Replace with real summary data when available.
    printf '{\n  "status": "completed"\n}\n' > "$RESULT_JSON"

    echo "Job finished on $(date)"
) > "$LOG_DIR/stdout.log" 2> "$LOG_DIR/stderr.log"
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
    uph_json_status completed
else
    uph_json_status failed "Command exited with status $exit_code"
fi

exit "$exit_code"
EOF
    chmod +x "$out_file"
    _uph_success "Created Cockpit-compatible Slurm template: $out_file"
}

slog() {
    local latest_log
    latest_log=$(ls -t slurm-*.out 2>/dev/null | head -n 1)
    if [ -n "$latest_log" ]; then
        _uph_info "Tailing log: $latest_log"
        tail -f "$latest_log"
    else
        _uph_error "No slurm-*.out files found in this directory."
        return 1
    fi
}

# ==========================================
# Scratch, Lustre, and quota helpers
# ==========================================

_uph_lustre_mounts() {
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -rn -t lustre -o TARGET 2>/dev/null
    elif [ -r /proc/mounts ]; then
        awk '$3 == "lustre" { print $2 }' /proc/mounts
    elif command -v mount >/dev/null 2>&1; then
        mount | awk '$0 ~ / type lustre / { print $3 }'
    fi
}

lustreinfo() {
    local mounts
    mounts=$(_uph_lustre_mounts)
    if [ -z "$mounts" ]; then
        _uph_warn "No Lustre mount was detected."
        return 1
    fi
    _uph_info "Detected Lustre mounts:"
    printf '%s\n' "$mounts"
    if command -v lfs >/dev/null 2>&1; then
        _uph_info "Lustre client:"
        lfs --version 2>/dev/null | head -n 1
    fi
}

# Detect the most likely user/project scratch path without creating directories.
hpc_find_scratch() {
    local candidate mount

    for candidate in \
        "${UPH_SCRATCH_DIR:-}" \
        "${SCRATCH:-}" \
        "${WORK:-}" \
        "/scratch/$USER" \
        "/work/$USER" \
        "/lustre/$USER" \
        "/mnt/scratch/$USER" \
        "/local/$USER"
    do
        [ -n "$candidate" ] || continue
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        if [ -d "${candidate%/*}" ] && [ -w "${candidate%/*}" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    while IFS= read -r mount; do
        [ -n "$mount" ] || continue
        for candidate in "$mount/$USER" "$mount/users/$USER" "$mount/home/$USER"; do
            if [ -d "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
            if [ -d "${candidate%/*}" ] && [ -w "${candidate%/*}" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done <<EOF
$(_uph_lustre_mounts)
EOF

    return 1
}

mkscratch() {
    local scratch_path="${1:-}"
    local parent

    if [ -z "$scratch_path" ]; then
        scratch_path=$(hpc_find_scratch) || true
    fi
    if [ -z "$scratch_path" ]; then
        _uph_error "No user scratch directory was detected."
        echo "Set UPH_SCRATCH_DIR in ~/.config/hpc/local.sh."
        echo "Detected Lustre mounts:"
        _uph_lustre_mounts | sed 's/^/  /'
        return 1
    fi

    if [ ! -d "$scratch_path" ]; then
        parent=${scratch_path%/*}
        if [ ! -d "$parent" ] || [ ! -w "$parent" ]; then
            _uph_error "Scratch path does not exist and its parent is not writable: $scratch_path"
            return 1
        fi
        mkdir -p "$scratch_path" || return 1
        _uph_success "Created scratch directory: $scratch_path"
    fi

    if [ -e "$HOME/scratch" ] && [ ! -L "$HOME/scratch" ]; then
        _uph_warn "$HOME/scratch exists and is not a symlink; leaving it unchanged."
    elif [ -L "$HOME/scratch" ]; then
        ln -sfn "$scratch_path" "$HOME/scratch"
    else
        ln -s "$scratch_path" "$HOME/scratch"
        _uph_success "Created symlink: ~/scratch -> $scratch_path"
    fi

    cd "$scratch_path" || return 1
}

# Report filesystem usage and Lustre or POSIX quota information for a path.
myquota() {
    local target="${1:-$(hpc_find_scratch 2>/dev/null || printf '%s' "$HOME")}"
    local quota_group="${UPH_QUOTA_GROUP:-}"
    _uph_info "Filesystem usage for $target:"
    df -h "$target"

    if command -v lfs >/dev/null 2>&1; then
        if [ -n "$quota_group" ]; then
            _uph_info "Lustre group quota for $quota_group:"
            lfs quota -h -g "$quota_group" "$target" 2>/dev/null ||
                _uph_warn "The cluster did not return a group quota for $quota_group."
        else
            _uph_info "Lustre user quota for $USER:"
            lfs quota -h -u "$USER" "$target" 2>/dev/null ||
                _uph_warn "No user quota was returned. Set UPH_QUOTA_GROUP if this cluster uses group quotas."
        fi
    elif command -v quota >/dev/null 2>&1; then
        _uph_info "User quota:"
        quota -s 2>/dev/null || quota -v
    else
        _uph_warn "Neither lfs nor quota is available."
    fi
}

# ==========================================
# Environment modules and toolchains
# ==========================================

_uph_module_init() {
    command -v module >/dev/null 2>&1 && return 0
    for init_file in \
        /etc/profile.d/modules.sh \
        /usr/share/Modules/init/bash \
        /usr/share/lmod/lmod/init/bash
    do
        if [ -r "$init_file" ]; then
            # shellcheck disable=SC1090
            . "$init_file"
            command -v module >/dev/null 2>&1 && return 0
        fi
    done
    _uph_error "Environment Modules/Lmod is not available in this shell."
    return 1
}

modpurge() {
    _uph_module_init || return 1
    module purge
}

modlist() {
    _uph_module_init || return 1
    module list
}

modavail() {
    _uph_module_init || return 1
    module avail "$@"
}

modoverview() {
    _uph_module_init || return 1
    module overview "$@"
}

moddefaults() {
    _uph_module_init || return 1
    module -d avail "$@"
}

modreset() {
    _uph_module_init || return 1
    module reset
}

modshow() {
    _uph_module_init || return 1
    module show "$@"
}

modspider() {
    _uph_module_init || return 1
    module spider "$@"
}

modkeyword() {
    _uph_module_init || return 1
    module keyword "$@"
}

modhelp() {
    _uph_module_init || return 1
    module help "$@"
}

moduse() {
    _uph_module_init || return 1
    module use "$@"
}

modunload() {
    _uph_module_init || return 1
    module unload "$@"
}

modswap() {
    _uph_module_init || return 1
    module swap "$@"
}

software_find() {
    if [ "$#" -eq 0 ]; then
        echo "Usage: software_find <name-or-keyword>"
        return 1
    fi
    if command -v find_module >/dev/null 2>&1; then
        find_module "$@"
    elif command -v find_modules >/dev/null 2>&1; then
        find_modules "$@"
    else
        _uph_module_init || return 1
        module spider "$@" 2>/dev/null || module keyword "$@"
    fi
}

# Set a UPH_MODULE_<PROFILE> mapping, optionally persisting it in local.sh.
modset() {
    local persist=false
    local profile variable module_name config_file temp_file

    if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--persist" ]; then
        persist=true
        shift
    fi
    if [ "$#" -ne 2 ]; then
        echo "Usage: modset [-p|--persist] <profile> <module-name>"
        return 1
    fi

    profile="$1"
    module_name="$2"
    variable=$(_uph_module_var "$profile")
    if [ "$variable" = "UPH_MODULE_" ]; then
        _uph_error "Invalid module profile: $profile"
        return 2
    fi

    export "$variable=$module_name"
    _uph_success "Set $variable=$module_name"

    if [ "$persist" = true ]; then
        config_file="$HOME/.config/hpc/local.sh"
        mkdir -p "${config_file%/*}" || return 1
        temp_file=$(mktemp "${config_file}.tmp.XXXXXX") || return 1
        if [ -f "$config_file" ]; then
            awk -v variable="$variable" '
                $0 !~ "^[[:space:]]*(export[[:space:]]+)?" variable "=" { print }
            ' "$config_file" > "$temp_file"
        fi
        printf "export %s='%s'\n" "$variable" "$(printf '%s' "$module_name" | sed "s/'/'\\\\''/g")" >> "$temp_file"
        mv "$temp_file" "$config_file"
        chmod 600 "$config_file"
        _uph_success "Persisted $variable in $config_file"
    fi
}

# Show one module mapping or all UPH_MODULE_* mappings.
modget() {
    local profile variable value

    if [ "$#" -eq 0 ]; then
        env | LC_ALL=C sort | sed -n '/^UPH_MODULE_[A-Z0-9_]*=/p'
        return 0
    fi
    if [ "$#" -ne 1 ]; then
        echo "Usage: modget [profile]"
        return 1
    fi

    profile="$1"
    variable=$(_uph_module_var "$profile")
    value=$(_uph_module_get "$profile")
    if [ -n "$value" ]; then
        printf '%s=%s\n' "$variable" "$value"
    else
        _uph_warn "$variable is not set."
        return 1
    fi
}

# Remove a UPH_MODULE_<PROFILE> mapping, optionally from local.sh.
modunset() {
    local persist=false
    local profile variable config_file temp_file

    if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--persist" ]; then
        persist=true
        shift
    fi
    if [ "$#" -ne 1 ]; then
        echo "Usage: modunset [-p|--persist] <profile>"
        return 1
    fi

    profile="$1"
    variable=$(_uph_module_var "$profile")
    unset "$variable"
    _uph_success "Unset $variable"

    if [ "$persist" = true ]; then
        config_file="$HOME/.config/hpc/local.sh"
        if [ -f "$config_file" ]; then
            temp_file=$(mktemp "${config_file}.tmp.XXXXXX") || return 1
            awk -v variable="$variable" '
                $0 !~ "^[[:space:]]*(export[[:space:]]+)?" variable "=" { print }
            ' "$config_file" > "$temp_file"
            mv "$temp_file" "$config_file"
            chmod 600 "$config_file"
            _uph_success "Removed $variable from $config_file"
        fi
    fi
}

_uph_module_try() {
    local candidate
    _uph_module_init || return 1
    for candidate in "$@"; do
        [ -n "$candidate" ] || continue
        if module load "$candidate" >/dev/null 2>&1; then
            _uph_success "Loaded module: $candidate"
            return 0
        fi
    done
    _uph_warn "No matching module loaded from: $*"
    return 1
}

_uph_module_try_profile() {
    local profile="$1"
    local configured
    shift
    configured=$(_uph_module_get "$profile")
    _uph_module_try "$configured" "$@"
}

_uph_modload_profile() {
    local configured
    case "$1" in
        compiler|cpp|cxx|fortran)
            _uph_module_try_profile compiler GCC gcc intel-oneapi-compilers intel oneapi ||
                return 1
            ;;
        mpi)
            _uph_module_try_profile mpi OpenMPI openmpi MPI impi ||
                return 1
            ;;
        hdf5)
            _uph_module_try_profile hdf5 HDF5 hdf5 HDF5-parallel hdf5-parallel ||
                return 1
            ;;
        python)
            _uph_module_try_profile python Python python Anaconda3 Miniconda3 ||
                return 1
            ;;
        julia)
            _uph_module_try_profile julia Julia julia ||
                return 1
            ;;
        container|apptainer|singularity)
            _uph_module_try_profile container Apptainer apptainer Singularity singularity ||
                return 1
            ;;
        cmake)
            _uph_module_try_profile cmake CMake cmake ||
                return 1
            ;;
        blas|lapack|math)
            _uph_module_try_profile blas OpenBLAS FlexiBLAS BLAS LAPACK imkl ||
                return 1
            ;;
        boost)
            _uph_module_try_profile boost Boost boost ||
                return 1
            ;;
        netcdf)
            _uph_module_try_profile netcdf netCDF NetCDF netcdf ||
                return 1
            ;;
        *)
            configured=$(_uph_module_get "$1")
            if [ -n "$configured" ]; then
                _uph_module_try "$configured"
            else
                _uph_error "Unknown module profile: $1"
                echo "Define it with: modset $1 <module-name>" >&2
                return 1
            fi
            ;;
    esac
}

# Load one or more generic module profiles using configured mappings first.
modload() {
    local profile
    local failed=0

    if [ "$#" -eq 0 ]; then
        echo "Usage: modload <cpp|fortran|mpi|hdf5|python|julia|container|cmake|math|boost|netcdf|science> [...]"
        return 1
    fi
    _uph_module_init || return 1

    for profile in "$@"; do
        case "$profile" in
            science)
                _uph_modload_profile cpp || failed=1
                _uph_modload_profile mpi || failed=1
                _uph_modload_profile hdf5 || failed=1
                _uph_modload_profile math || failed=1
                _uph_modload_profile python || failed=1
                _uph_modload_profile cmake || failed=1
                ;;
            *)
                _uph_modload_profile "$profile" || failed=1
                ;;
        esac
    done
    module list
    return "$failed"
}

modload_cpp() {
    modload cpp cmake
}

modload_fortran() {
    modload fortran cmake
}

modload_python() {
    modload python
}

modload_julia() {
    modload julia
}

modload_container() {
    modload container
}

modload_hdf5() {
    modload cpp mpi hdf5
}

modload_science() {
    modload science
}

# ==========================================
# Help and session diagnostics
# ==========================================

hpchelp() {
    cat <<'EOF'
Remote HPC helper commands

Jobs:
  sq, sqr, sqc, sqn, sqnr       inspect your queue
  sac, jobeff JOBID             inspect completed jobs
  jobtop JOBID                  run htop/top inside a job
  inter [options]               request an interactive srun shell
  sub-interactive [options]     same as inter; use -h for all options
  salloc_quick [CPUS TIME PART] request an allocation
  mkslurm FILE                  create a batch script template
  mkslurm_cockpit FILE          create a Cockpit-compatible batch template
  scanc JOBID, scancall         cancel one/all jobs
  slog                          follow the newest slurm-*.out

Runs:
  common-run.sh                 generic run/log/manifest helper layer
  uph_make_run_dir NAME         create RUN_DIR with logs, output, tmp files
  uph_run NAME COMMAND [ARGS]   run a command with logs and status JSON
  uph_json_status STATUS [MSG]  write status.json
  uph_write_manifest [CMD...]   write manifest.txt for the current run
  uph_write_git_manifest [REPO] write git.txt with commit/status details

Storage:
  lustreinfo                    list detected Lustre mounts
  hpc_find_scratch              print the detected user scratch path
  mkscratch [PATH]              link ~/scratch and enter it
  myquota [PATH]                show filesystem and Lustre quota usage

Modules:
  software_find QUERY           use site search helper or Lmod search
  modset [-p] PROFILE MODULE    map a profile to a module name
  modget [PROFILE]              show one/all module mappings
  modunset [-p] PROFILE         remove a module mapping
  modpurge, modreset, modlist   clear/reset/list loaded modules
  modavail, moddefaults         list available/default modules
  modoverview                   summarize versions by short name
  modshow, modspider, modkeyword inspect/search module metadata
  modhelp, moduse               show help/add a MODULEPATH
  modunload, modswap            change loaded modules
  modload PROFILE [...]         load cpp, fortran, mpi, hdf5, python,
                                julia, container, cmake, math, boost,
                                netcdf, or science
  modload_cpp                   load compiler and CMake
  modload_fortran               load compiler and CMake
  modload_hdf5                  load compiler, MPI, and HDF5
  modload_python                load Python
  modload_julia                 load Julia
  modload_container             load Apptainer/Singularity
  modload_science               load the combined scientific stack

Cluster-specific defaults can be set with UPH_SLURM_*, UPH_SCRATCH_DIR,
UPH_QUOTA_GROUP, and generic UPH_MODULE_<PROFILE> variables. Use
modset --persist to create or update module mappings in ~/.config/hpc/local.sh.
EOF
}

hpcdoctor() {
    local command_name
    _uph_info "Shell: ${SHELL:-unknown}"
    for command_name in srun squeue sacct sinfo module find_module findmnt lfs apptainer singularity; do
        if command -v "$command_name" >/dev/null 2>&1; then
            printf '  %-8s %s\n' "$command_name" "$(command -v "$command_name")"
        else
            printf '  %-8s %s\n' "$command_name" "not found"
        fi
    done
    printf '  %-8s %s\n' "scratch" "$(hpc_find_scratch 2>/dev/null || echo 'not detected')"
}

tmux_guard() {
    if command -v tmux >/dev/null 2>&1 &&
        [ -z "${TMUX:-}" ] &&
        [ -n "${SSH_CONNECTION:-}" ] &&
        [ -t 1 ]; then
        _uph_warn "Tip: protect long login sessions with: tmux attach || tmux"
    fi
}

tmux_guard
