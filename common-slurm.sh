# Slurm and module helpers for Bash and Zsh, for example from ~/.bashrc.
# Cluster settings come from the active profile (see common-profile.sh); this
# file contains no site-specific values.
# shellcheck shell=bash

if [ -n "${BASH_VERSION:-}" ]; then
    _hpc_self=${BASH_SOURCE[0]}
elif [ -n "${ZSH_VERSION:-}" ]; then
    _hpc_self=${(%):-%x}
else
    _hpc_self=$0
fi
HPC_HELPER_DIR="${HPC_HELPER_DIR:-$(CDPATH= cd -- "$(dirname -- "$_hpc_self")" 2>/dev/null && pwd)}"
unset _hpc_self

for _hpc_dep in common-profile.sh common-run.sh; do
    # shellcheck disable=SC1090
    [ -r "$HPC_HELPER_DIR/$_hpc_dep" ] && . "$HPC_HELPER_DIR/$_hpc_dep"
done
unset _hpc_dep

_hpc_info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
_hpc_ok() { printf '\033[1;32m%s\033[0m\n' "$*"; }
_hpc_warn() { printf '\033[1;33m%s\033[0m\n' "$*" >&2; }
_hpc_error() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

_hpc_require() {
    command -v "$1" >/dev/null 2>&1 && return 0
    _hpc_error "Required command not found: $1"
    return 1
}

# ==========================================
# Profiles
# ==========================================

hpcprofile() {
    case "${1:-show}" in
        list|ls) hpc_profile_list ;;
        use|load)
            [ -n "${2:-}" ] || { _hpc_error "Usage: hpcprofile use <name>"; return 1; }
            hpc_profile_load "$2" || return 1
            _hpc_ok "Active profile: $HPC_PROFILE"
            ;;
        show) hpc_profile_show ;;
        path) hpc_profile_path "${2:-}" || return 1 ;;
        dir) printf '%s\n' "$HPC_PROFILE_DIR" ;;
        *)
            echo "Usage: hpcprofile [list|use NAME|show|path [NAME]|dir]" >&2
            return 1
            ;;
    esac
}

# ==========================================
# Queue and accounting
# ==========================================

alias sq='squeue -u "$USER" --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'
alias sqr='squeue -u "$USER" -t running --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'
alias sqn='squeue -u "$USER" -h -t pending,running -r | wc -l'
alias sac='sacct --starttime=midnight --format=JobID,jobname,partition,ncpus,nodelist,nnodes,AveCPU,totalcpu,MaxRSS,ReqMem,elapsed,state,exitcode'

sqc() {
    squeue -u "$USER" --format='%.8i %.9P %.18j %.8u %.2t %.10M %.6D %R' |
        awk 'NR == 1 { print; next }
             $5 == "R"  { print "\033[1;32m" $0 "\033[0m"; next }
             $5 == "PD" { print "\033[1;33m" $0 "\033[0m"; next }
             $5 == "CG" { print "\033[1;31m" $0 "\033[0m"; next }
             { print }'
}

jobeff() {
    [ -n "${1:-}" ] || { echo "Usage: jobeff <job_id>" >&2; return 1; }
    if command -v seff >/dev/null 2>&1; then
        seff "$1"
    else
        _hpc_require sacct || return 1
        sacct -j "$1" --format=JobID,JobName,Partition,MaxRSS,Elapsed,State,ExitCode
    fi
}

jobtop() {
    [ -n "${1:-}" ] || { echo "Usage: jobtop <job_id>" >&2; return 1; }
    if command -v htop >/dev/null 2>&1; then
        srun --jobid="$1" --pty htop
    else
        srun --jobid="$1" --pty top
    fi
}

# ==========================================
# Interactive jobs
# ==========================================

# Render scheduler options shared by inter/salloc/mkslurm.
_hpc_slurm_options() {
    local cpus=$1 time=$2 mem=$3 partition=$4 account=$5 qos=$6 gpus=$7 nodes=$8
    printf '%s\n' "--nodes=${nodes:-1}" "--ntasks=1" "--cpus-per-task=$cpus" "--time=$time"
    [ -n "$mem" ] && printf '%s\n' "--mem=$mem"
    [ -n "$partition" ] && printf '%s\n' "--partition=$partition"
    [ -n "$account" ] && printf '%s\n' "--account=$account"
    [ -n "$qos" ] && printf '%s\n' "--qos=$qos"
    if [ -n "$gpus" ]; then
        case "${HPC_SLURM_GPU_STYLE:-gres}" in
            gpus) printf '%s\n' "--gpus=$gpus" ;;
            gpus-per-node) printf '%s\n' "--gpus-per-node=$gpus" ;;
            *) printf '%s\n' "--gres=gpu:$gpus" ;;
        esac
    fi
    [ -n "${HPC_SLURM_MAIL:-}" ] && printf '%s\n' "--mail-user=$HPC_SLURM_MAIL" "--mail-type=END,FAIL"
    [ "${#HPC_SLURM_EXTRA[@]}" -gt 0 ] && printf '%s\n' "${HPC_SLURM_EXTRA[@]}"
    return 0
}

sub-interactive() {
    local cpus="${HPC_SLURM_CPUS:-1}" time="${HPC_SLURM_TIME:-01:00:00}"
    local mem="${HPC_SLURM_MEM:-}" partition="${HPC_SLURM_PARTITION:-}"
    local account="${HPC_SLURM_ACCOUNT:-}" qos="${HPC_SLURM_QOS:-}"
    local gpus="${HPC_SLURM_GPUS:-}" shell_path="${HPC_SHELL:-${SHELL:-/bin/bash}}"
    local opt
    local -a options

    OPTIND=1
    while getopts ":c:t:m:p:A:q:g:s:h" opt; do
        case "$opt" in
            c) cpus=$OPTARG ;;
            t) time=$OPTARG ;;
            m) mem=$OPTARG ;;
            p) partition=$OPTARG ;;
            A) account=$OPTARG ;;
            q) qos=$OPTARG ;;
            g) gpus=$OPTARG ;;
            s) shell_path=$OPTARG ;;
            h)
                cat <<'EOF'
Usage: inter [-c cpus] [-t time] [-m memory] [-p partition]
             [-A account] [-q qos] [-g gpus] [-s shell]

Defaults come from the active HPC profile (HPC_SLURM_*).
GPU examples: -g 1, -g a100:2
EOF
                return 0
                ;;
            :) _hpc_error "Option -$OPTARG requires a value."; return 2 ;;
            \?) _hpc_error "Unknown option: -$OPTARG"; return 2 ;;
        esac
    done
    shift $((OPTIND - 1))

    _hpc_require srun || return 1
    case "$mem" in none|default) mem="" ;; *[!0-9]*) ;; *) mem="${mem}G" ;; esac
    [ -x "$shell_path" ] || shell_path=$(command -v bash || command -v sh)

    while IFS= read -r opt; do
        options+=("$opt")
    done <<EOF
$(_hpc_slurm_options "$cpus" "$time" "$mem" "$partition" "$account" "$qos" "$gpus" "${HPC_SLURM_NODES:-1}")
EOF
    _hpc_info "Requesting: srun ${options[*]} --pty $shell_path -l"
    srun "${options[@]}" --pty "$shell_path" -l
}

inter() { sub-interactive "$@"; }

salloc_quick() {
    local cpus="${1:-${HPC_SLURM_CPUS:-4}}" time="${2:-${HPC_SLURM_TIME:-02:00:00}}"
    local partition="${3:-${HPC_SLURM_PARTITION:-}}" opt
    local -a options

    _hpc_require salloc || return 1
    while IFS= read -r opt; do
        options+=("$opt")
    done <<EOF
$(_hpc_slurm_options "$cpus" "$time" "${HPC_SLURM_MEM:-}" "$partition" "${HPC_SLURM_ACCOUNT:-}" "${HPC_SLURM_QOS:-}" "${HPC_SLURM_GPUS:-}" "${HPC_SLURM_NODES:-1}")
EOF
    _hpc_info "Requesting: salloc ${options[*]}"
    salloc "${options[@]}"
}

# ==========================================
# Script templates
# ==========================================

_hpc_sbatch_header() {
    local name=$1 opt
    printf '#!/bin/bash\n'
    printf '#SBATCH --job-name=%s\n' "$name"
    printf '#SBATCH --output=slurm-%%j.out\n'
    printf '#SBATCH --error=slurm-%%j.err\n'
    while IFS= read -r opt; do
        printf '#SBATCH %s\n' "$opt"
    done <<EOF
$(_hpc_slurm_options "${HPC_SLURM_CPUS:-4}" "${HPC_SLURM_TIME:-12:00:00}" "${HPC_SLURM_MEM:-}" "${HPC_SLURM_PARTITION:-}" "${HPC_SLURM_ACCOUNT:-}" "${HPC_SLURM_QOS:-}" "${HPC_SLURM_GPUS:-}" "${HPC_SLURM_NODES:-1}")
EOF
    printf '\nset -euo pipefail\n\n'
}

mkslurm() {
    [ -n "${1:-}" ] || { echo "Usage: mkslurm <script.sh>" >&2; return 1; }
    local out=$1
    case "$out" in *.sh) ;; *) out="$out.sh" ;; esac
    [ -e "$out" ] && { _hpc_error "File exists: $out"; return 1; }

    {
        _hpc_sbatch_header "scientific-job"
        printf 'echo "Started $(date) on ${SLURM_NODELIST:-unknown}"\n\n'
        printf '# module load ...\n'
        printf '# Replace with the workload:\n'
        printf '# srun --ntasks=1 --cpus-per-task="${SLURM_CPUS_PER_TASK:-1}" ./solver\n\n'
        printf 'echo "Finished $(date)"\n'
    } > "$out"
    chmod +x "$out"
    _hpc_ok "Created Slurm template: $out"
}

slog() {
    local latest
    latest=$(ls -t slurm-*.out 2>/dev/null | head -n 1)
    [ -n "$latest" ] || { _hpc_error "No slurm-*.out in this directory."; return 1; }
    _hpc_info "Tailing $latest"
    tail -f "$latest"
}

# ==========================================
# Storage
# ==========================================

_hpc_lustre_mounts() {
    if command -v findmnt >/dev/null 2>&1; then
        findmnt -rn -t lustre -o TARGET 2>/dev/null
    elif [ -r /proc/mounts ]; then
        awk '$3 == "lustre" { print $2 }' /proc/mounts
    fi
}

hpc_find_scratch() {
    local candidate mount
    for candidate in \
        "${HPC_SCRATCH_DIR:-}" "${SCRATCH:-}" "${WORK:-}" \
        "/scratch/$USER" "/work/$USER" "/lustre/$USER" "/mnt/scratch/$USER"
    do
        [ -n "$candidate" ] || continue
        [ -d "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
    done
    while IFS= read -r mount; do
        for candidate in "$mount/$USER" "$mount/users/$USER"; do
            [ -d "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
        done
    done <<EOF
$(_hpc_lustre_mounts)
EOF
    return 1
}

mkscratch() {
    local target="${1:-}" parent
    [ -n "$target" ] || target=$(hpc_find_scratch) || true
    if [ -z "$target" ]; then
        _hpc_error "No scratch directory detected. Set HPC_SCRATCH_DIR in the profile."
        return 1
    fi
    if [ ! -d "$target" ]; then
        parent=${target%/*}
        [ -d "$parent" ] && [ -w "$parent" ] || {
            _hpc_error "Cannot create $target"; return 1; }
        mkdir -p "$target" || return 1
        _hpc_ok "Created $target"
    fi
    if [ ! -e "$HOME/scratch" ]; then
        ln -s "$target" "$HOME/scratch"
        _hpc_ok "Linked ~/scratch -> $target"
    fi
    cd "$target" || return 1
}

myquota() {
    local target="${1:-$(hpc_find_scratch 2>/dev/null || printf '%s' "$HOME")}"
    local group="${HPC_QUOTA_GROUP:-}"
    _hpc_info "Usage for $target:"
    df -h "$target"
    if command -v lfs >/dev/null 2>&1; then
        if [ -n "$group" ]; then
            lfs quota -h -g "$group" "$target" 2>/dev/null || _hpc_warn "No group quota for $group."
        else
            lfs quota -h -u "$USER" "$target" 2>/dev/null || _hpc_warn "No user quota; set HPC_QUOTA_GROUP if needed."
        fi
    elif command -v quota >/dev/null 2>&1; then
        quota -s 2>/dev/null || quota -v
    fi
}

# ==========================================
# Modules
# ==========================================

# Run `module ARGS` after making sure the command exists.
mod() { hpc_module_init && module "$@"; }

# With no arguments, load the active profile's module list.
modload() {
    local m failed=0
    hpc_module_init || return 1
    if [ "$#" -eq 0 ]; then
        [ "${#HPC_ENV_MODULES[@]}" -gt 0 ] || {
            _hpc_warn "No modules in profile. Usage: modload MODULE [...]"; return 1; }
        set -- "${HPC_ENV_MODULES[@]}"
    fi
    for m in "$@"; do
        if module load "$m" >/dev/null 2>&1; then
            _hpc_ok "Loaded $m"
        else
            _hpc_warn "Could not load $m"
            failed=1
        fi
    done
    module list
    return "$failed"
}

# ==========================================
# Diagnostics
# ==========================================

hpchelp() {
    cat <<'EOF'
Profiles:  hpcprofile list|use NAME|show|path|dir   (NAME or NAME:RUN)
Queue:     sq, sqr, sqc, sqn      your jobs; sac  today's accounting
Jobs:      jobeff ID, jobtop ID, slog (follow newest slurm-*.out)
Allocate:  inter [-c -t -m -p -A -q -g -s] (inter -h), salloc_quick [CPUS TIME PART]
Scripts:   mkslurm FILE          sbatch template from the active profile
Modules:   modload [MODULE ...]  profile modules or the given ones; mod ARGS = module ARGS
Storage:   hpc_find_scratch, mkscratch, myquota
Runs:      uph_make_run_dir NAME, uph_run NAME COMMAND [...]  (common-run.sh)
Check:     hpcdoctor
EOF
}

hpcdoctor() {
    local c
    _hpc_info "Profile: ${HPC_PROFILE:-<none>}"
    _hpc_info "Shell: ${SHELL:-unknown}"
    for c in srun squeue sacct sinfo module findmnt lfs apptainer; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '  %-9s %s\n' "$c" "$(command -v "$c")"
        else
            printf '  %-9s %s\n' "$c" "not found"
        fi
    done
    printf '  %-9s %s\n' scratch "$(hpc_find_scratch 2>/dev/null || echo 'not detected')"
}

# Nudge once per interactive SSH login; long jobs should survive a dropped link.
case $- in
    *i*)
        if command -v tmux >/dev/null 2>&1 && [ -z "${TMUX:-}" ] && [ -n "${SSH_CONNECTION:-}" ]; then
            _hpc_warn "Tip: protect long sessions with: tmux attach || tmux"
        fi
        ;;
esac
