# Portable Slurm and HPC cluster shell helpers.
# Source from Bash or Zsh, for example from ~/.bashrc or ~/.zshrc.

# Optional per-cluster overrides:
#   UPH_SLURM_PARTITION=normal
#   UPH_SLURM_ACCOUNT=my-project
#   UPH_SLURM_QOS=normal
#   UPH_INTERACTIVE_SHELL=/bin/bash
#   UPH_SCRATCH_DIR=/lustre/project/user
#   UPH_PC2_PROJECT=hpc-prf-example
#   UPH_MODULE_COMPILER="GCC/13.2.0"
#   UPH_MODULE_MPI="OpenMPI/4.1.6"
#   UPH_MODULE_HDF5="HDF5/1.14.3"
#   UPH_MODULE_PYTHON="Python/3.11"
#   UPH_MODULE_BLAS="OpenBLAS/0.3.26"
#   UPH_MODULE_BOOST="Boost/1.84.0"
#   UPH_MODULE_NETCDF="netCDF/4.9.2"

if [ -r "$HOME/.config/hpc/local.sh" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.config/hpc/local.sh"
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

_uph_slurm_init() {
    local candidate

    command -v srun >/dev/null 2>&1 && return 0
    _uph_module_init >/dev/null 2>&1 || true

    if command -v module >/dev/null 2>&1; then
        for candidate in "${UPH_MODULE_SLURM:-}" slurm system/slurm; do
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

sub-interactive() {
    local cores="${UPH_SLURM_CPUS:-1}"
    local walltime="${UPH_SLURM_TIME:-01:00:00}"
    local memory="${UPH_SLURM_MEMORY:-1G}"
    local partition="${UPH_SLURM_PARTITION:-}"
    local account="${UPH_SLURM_ACCOUNT:-${SLURM_ACCOUNT:-${SBATCH_ACCOUNT:-}}}"
    local qos="${UPH_SLURM_QOS:-}"
    local gpu_request="${UPH_SLURM_GRES:-${UPH_SLURM_GPUS:-}}"
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

inter_gpu() {
    local gpu_count="${1:-1}"
    local gpu_type="${UPH_GPU_TYPE:-a100}"
    local partition="${UPH_GPU_DEVEL_PARTITION:-dgx}"
    local qos="${UPH_GPU_DEVEL_QOS:-devel}"
    local cores_per_gpu="${UPH_GPU_CORES_PER_GPU:-16}"
    local minutes cores

    case "$gpu_count" in
        ''|*[!0-9]*) _uph_error "Usage: inter_gpu [gpu-count: 1-8]"; return 2 ;;
    esac
    if [ "$gpu_count" -lt 1 ] || [ "$gpu_count" -gt 8 ]; then
        _uph_error "Noctua 2 development sessions support 1-8 GPUs."
        return 2
    fi

    minutes=$((270 - 30 * gpu_count))
    cores=$((cores_per_gpu * gpu_count))
    _uph_info "Noctua 2 development allocation: $gpu_count $gpu_type GPU(s), $cores CPU cores, $minutes minutes."
    sub-interactive \
        -c "$cores" \
        -t "$minutes" \
        -m "${UPH_GPU_MEMORY:-default}" \
        -p "$partition" \
        -q "$qos" \
        -g "$gpu_type:$gpu_count"
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

# Adjust these modules to the cluster, or source common-slurm.sh and run:
# modload cpp mpi hdf5 python
if command -v module >/dev/null 2>&1; then
    module purge
    module load GCC OpenMPI HDF5 Python
fi

echo "Job started on $(date) on ${SLURM_NODELIST:-unknown node}"

# srun --ntasks=1 --cpus-per-task="$SLURM_CPUS_PER_TASK" ./solver
# srun python solver.py

echo "Job finished on $(date)"
EOF
    chmod +x "$out_file"
    _uph_success "Created Slurm submission template: $out_file"
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

pc2projects() {
    local base="${PC2PFS:-/scratch}"
    local group
    local found=0

    _uph_info "PC2 project storage candidates under $base:"
    for group in $(id -Gn 2>/dev/null); do
        case "$group" in
            hpc-*|pc2-*)
                if [ -d "$base/$group" ]; then
                    printf '  %s\n' "$base/$group"
                    found=1
                fi
                ;;
        esac
    done
    if [ "$found" -eq 0 ]; then
        _uph_warn "No project directory matched your hpc-*/pc2-* groups."
        echo "Groups: $(id -Gn 2>/dev/null)"
        return 1
    fi
}

pc2info() {
    printf '%-12s %s\n' "PC2DATA" "${PC2DATA:-not set}"
    printf '%-12s %s\n' "PC2PFS" "${PC2PFS:-not set}"
    printf '%-12s %s\n' "PC2PFSN2" "${PC2PFSN2:-not set}"
    printf '%-12s %s\n' "project" "${UPH_PC2_PROJECT:-not set}"
    printf '%-12s %s\n' "scratch" "$(hpc_find_scratch 2>/dev/null || echo 'not detected')"
    if command -v pc2status >/dev/null 2>&1; then
        _uph_info "pc2status:"
        pc2status
    fi
}

hpc_find_scratch() {
    local candidate mount group
    local pc2_base="${PC2PFS:-}"
    local matches=""
    local match_count=0

    if [ -n "${UPH_PC2_PROJECT:-}" ] && [ -n "$pc2_base" ]; then
        candidate="$pc2_base/$UPH_PC2_PROJECT"
        if [ -d "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    fi

    for candidate in \
        "${UPH_SCRATCH_DIR:-}" \
        "${SCRATCH:-}" \
        "${PC2PFS_PROJECT:-}" \
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

    if [ -n "$pc2_base" ] && [ -d "$pc2_base" ]; then
        for group in $(id -Gn 2>/dev/null); do
            case "$group" in
                hpc-*|pc2-*)
                    candidate="$pc2_base/$group"
                    if [ -d "$candidate" ] && [ -w "$candidate" ]; then
                        matches="${matches}${candidate}
"
                        match_count=$((match_count + 1))
                    fi
                    ;;
            esac
        done
        if [ "$match_count" -eq 1 ]; then
            printf '%s' "$matches"
            return 0
        fi
    fi

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
        echo "Set UPH_SCRATCH_DIR or UPH_PC2_PROJECT in ~/.config/hpc/local.sh."
        if [ -n "${PC2PFS:-}" ]; then
            echo "PC2PFS=$PC2PFS"
            pc2projects 2>/dev/null || true
        fi
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

myquota() {
    local target="${1:-$(hpc_find_scratch 2>/dev/null || printf '%s' "$HOME")}"
    local project="${UPH_PC2_PROJECT:-}"
    _uph_info "Filesystem usage for $target:"
    df -h "$target"

    if command -v lfs >/dev/null 2>&1; then
        if [ -n "$project" ]; then
            _uph_info "Lustre group quota for $project:"
            lfs quota -h -g "$project" "${PC2PFS:-$target}" 2>/dev/null ||
                _uph_warn "The cluster did not return a group quota for $project."
        else
            _uph_info "Lustre user quota for $USER:"
            lfs quota -h -u "$USER" "$target" 2>/dev/null ||
                _uph_warn "No user quota was returned. PC2 commonly uses project/group quotas; set UPH_PC2_PROJECT."
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

_uph_modload_profile() {
    case "$1" in
        compiler|cpp|cxx|fortran)
            _uph_module_try "${UPH_MODULE_COMPILER:-}" compilers/GCC compiler/GCC GCC gcc intel-oneapi-compilers intel oneapi ||
                return 1
            ;;
        mpi)
            _uph_module_try "${UPH_MODULE_MPI:-}" mpi/OpenMPI OpenMPI openmpi MPI impi ||
                return 1
            ;;
        hdf5)
            _uph_module_try "${UPH_MODULE_HDF5:-}" data/HDF5 lib/HDF5 HDF5 hdf5 HDF5-parallel hdf5-parallel ||
                return 1
            ;;
        python)
            _uph_module_try "${UPH_MODULE_PYTHON:-}" lang/Python lang/Miniforge3 Python python Anaconda3 Miniconda3 ||
                return 1
            ;;
        julia)
            _uph_module_try "${UPH_MODULE_JULIA:-}" lang/JuliaHPC lang/Julia JuliaHPC Julia julia ||
                return 1
            ;;
        container|apptainer|singularity)
            if ! _uph_module_try "${UPH_MODULE_CONTAINER:-}" system/Apptainer system/Singularity system/singularity Apptainer apptainer Singularity singularity; then
                _uph_module_init || return 1
                module load system >/dev/null 2>&1 || return 1
                _uph_module_try Apptainer apptainer Singularity singularity || return 1
            fi
            ;;
        cmake)
            _uph_module_try "${UPH_MODULE_CMAKE:-}" devel/CMake tools/CMake CMake cmake ||
                return 1
            ;;
        blas|lapack|math)
            _uph_module_try "${UPH_MODULE_BLAS:-}" numlib/OpenBLAS lib/FlexiBLAS OpenBLAS FlexiBLAS BLAS LAPACK imkl ||
                return 1
            ;;
        boost)
            _uph_module_try "${UPH_MODULE_BOOST:-}" lib/Boost Boost boost ||
                return 1
            ;;
        netcdf)
            _uph_module_try "${UPH_MODULE_NETCDF:-}" data/netCDF data/NetCDF netCDF NetCDF netcdf ||
                return 1
            ;;
        *)
            _uph_error "Unknown module profile: $1"
            return 1
            ;;
    esac
}

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
  inter_gpu [COUNT]             Noctua 2 devel GPU session (1-8 GPUs)
  sub-interactive [options]     same as inter; use -h for all options
  salloc_quick [CPUS TIME PART] request an allocation
  mkslurm FILE                  create a batch script template
  scanc JOBID, scancall         cancel one/all jobs
  slog                          follow the newest slurm-*.out

Storage:
  lustreinfo                    list detected Lustre mounts
  pc2info, pc2projects          inspect PC2 storage and projects
  hpc_find_scratch              print the detected user scratch path
  mkscratch [PATH]              link ~/scratch and enter it
  myquota [PATH]                show filesystem and Lustre quota usage

Modules:
  software_find QUERY           use PC2 find_module or Lmod search
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
  modload_julia                 load JuliaHPC/Julia
  modload_container             load Apptainer/Singularity
  modload_science               load the combined scientific stack

Cluster-specific defaults can be set with UPH_SLURM_*, UPH_SCRATCH_DIR,
and the corresponding UPH_MODULE_* variables.
EOF
}

hpcdoctor() {
    local command_name
    _uph_info "Shell: ${SHELL:-unknown}"
    for command_name in srun squeue sacct sinfo module find_module pc2status findmnt lfs apptainer singularity; do
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
