# Portable Slurm and HPC Cluster Shell Environment Helpers
# Compatible with both BASH and ZSH. Copy this file to your remote cluster 
# (e.g., as ~/.config/hpc/common-slurm.sh) and source it in ~/.bashrc or ~/.zshrc.

# ==========================================
# 📊 Slurm Queue & Job Monitoring Aliases
# ==========================================

# 1. User-specific custom Slurm Queue monitoring (Generalized from user's defaults)
alias sq='squeue -u \$USER --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'
alias sqr='squeue -u \$USER -t running --Format=JobArrayID,partition,name,MaxCPUs,MinMemory,TimeUsed,TimeLeft,ReasonList,StateCompact,WorkDir'

# 2. Job counters (Running + Pending, or Running only)
alias sqn='squeue -u \$USER -h -t pending,running -r | wc -l'
alias sqnr='squeue -u \$USER -h -t running -r | wc -l'

# 3. Quick accounting check since midnight
alias sac='sacct --starttime=midnight --format=JobID,jobname,partition,ncpus,nodelist,nnodes,AveCPU,totalcpu,MaxRSS,ReqMem,AveRSS,AveVMSize,start,elapsed,state,exitcode'

# 4. Color-coded active queue (Running = Green, Pending = Yellow, Completing = Red)
alias sqc="squeue -u \$USER --format='%.8i %.9P %.18j %.8u %.2t %.10M %.6D %R' | awk '
  NR==1 {print \$0; next}
  \$5==\"R\"  {print \"\033[1;32m\"\$0\"\033[0m\"}   # Running
  \$5==\"PD\" {print \"\033[1;33m\"\$0\"\033[0m\"}   # Pending
  \$5==\"CG\" {print \"\033[1;31m\"\$0\"\033[0m\"}   # Completing
'"

# 5. Shorthands and Priority Checks
alias sqall="squeue --format='%.8i %.9P %.18j %.8u %.2t %.10M %.6D %R'"
alias sque="squeue"
alias sqh="squeue -h"
alias sprio_me="sprio -u \$USER"
alias sqpd="squeue -u \$USER -t PD -o '%.8i %.9P %.18j %.2t %R'"
alias jobnodes="squeue -u \$USER -o '%i %R' | grep -v 'NODELIST'"

# 3. View node partition availability and resource load
alias sinfo_avail="sinfo -s -p --format='%.10P %.5a %.10l %.16F'"

# 4. CPU/Memory resource utilization efficiency checker for COMPLETED jobs
# Essential for tuning Slurm walltime and RAM requests!
jobeff() {
    if [[ -z "$1" ]]; then
        echo "Usage: jobeff <job_id>"
        return 1
    fi
    if command -v seff >/dev/null 2>&1; then
        seff "$1"
    else
        sacct -j "$1" --format=JobID,JobName,Partition,MaxRSS,Elapsed,State,ExitCode
    fi
}

# 5. Interactive node shell monitor (HTOP on your allocated job node)
jobtop() {
    if [[ -z "$1" ]]; then
        echo "Usage: jobtop <job_id>"
        return 1
    fi
    echo -e "\033[1;34mRunning htop interactively on Node allocated to Job $1...\033[0m"
    srun --jobid="$1" --pty htop
}

# ==========================================
# ⚡ Job Control & Execution
# ==========================================

# Interactive node session wrapper (with native check and robust POSIX srun fallback)
sub-interactive() {
    # If a pre-configured sub-interactive binary/script exists on the host, execute it
    if command -v sub-interactive >/dev/null 2>&1; then
        command sub-interactive "$@"
        return $?
    fi

    # Fallback to general srun allocation
    local cores=1
    local hours=6
    local mem="1G"

    # Parse standard POSIX getopts flags
    OPTIND=1
    while getopts "c:t:m:" opt; do
        case "$opt" in
            c) cores="$OPTARG" ;;
            t) hours="$OPTARG" ;;
            m) mem="$OPTARG" ;;
            *) echo "Usage: sub-interactive [-c cores] [-t hours] [-m memory]" && return 1 ;;
        esac
    done
    shift $((OPTIND-1))

    # Clean mem units (append G if numeric only)
    if [[ "$mem" =~ ^[0-9]+$ ]]; then
        mem="${mem}G"
    fi

    # Clean time formatting (format to HH:MM:SS if numeric hours)
    local time_str="$hours"
    if [[ "$hours" =~ ^[0-9]+$ ]]; then
        time_str=$(printf "%02d:00:00" "$hours")
    fi

    echo -e "\033[1;34mAllocating interactive session:\033[0m srun -N1 -c$cores -t$time_str --mem=$mem --pty bash"
    srun -N1 -c"$cores" -t"$time_str" --mem="$mem" --pty bash
}

# Quick interactive allocations shorthand
alias inter='sub-interactive -c 1 -t 6 -m 1'

# Quick interactive node allocator (customize cores/walltime to your cluster partitions)
salloc_quick() {
    local cores="${1:-4}"
    local walltime="${2:-02:00:00}"
    local partition="${3}"
    
    local opts=(--nodes=1 --ntasks-per-node="$cores" --time="$walltime")
    if [[ -n "$partition" ]]; then
        opts+=(--partition="$partition")
    fi
    
    echo -e "\033[1;34mRequesting interactive shell: salloc ${opts[*]} --pty zsh\033[0m"
    salloc "${opts[@]}"
}

# Generate a high-performance Slurm submission script template
mkslurm() {
    if [[ -z "$1" ]]; then
        echo "Usage: mkslurm <script_name.sh>"
        return 1
    fi
    local out_file="$1"
    if [[ ! "$out_file" == *.sh ]]; then
        out_file="${out_file}.sh"
    fi
    if [[ -f "$out_file" ]]; then
        echo "Error: File $out_file already exists."
        return 1
    fi
    
    cat <<'EOF' > "$out_file"
#!/bin/bash
#SBATCH --job-name=scientific-job
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --partition=standard

# Exit on error
set -e

# Load the scientific computing environment modules
if command -v module >/dev/null 2>&1; then
    module purge
    module load gcc python openmpi
fi

echo "Job started on $(date) on node $SLURM_NODELIST"

# Run your high-performance solver/executable
# srun python solver.py

echo "Job finished on $(date)"
EOF
    chmod +x "$out_file"
    echo -e "\033[1;32mCreated Slurm submission template script:\033[0m $out_file"
}

# Cancel a specific job ID
alias scanc="scancel"

# Cancel ALL of your active/pending jobs instantly
alias scancall="scancel -u \$USER"

# Tailing Slurm output logs in real-time
slog() {
    local latest_log=$(ls -t slurm-*.out 2>/dev/null | head -n 1)
    if [[ -n "$latest_log" ]]; then
        echo -e "\033[1;34mTailing log: $latest_log\033[0m"
        tail -f "$latest_log"
    else
        echo "No slurm-*.out files found in this directory."
        return 1
    fi
}

# ==========================================
# 📂 Workspace & Storage Optimizations
# ==========================================

# Quick jump to cluster high-speed parallel scratch storage space
# Creates directory if it does not exist and creates a handy home-symlink
mkscratch() {
    local scratch_dirs=(
        "/scratch/$USER"
        "/work/$USER"
        "/local/$USER"
        "/mnt/scratch/$USER"
    )
    
    local scratch_path=""
    for dir in "${scratch_dirs[@]}"; do
        if [[ -d "${dir%/$USER}" ]]; then
            scratch_path="$dir"
            break
        fi
    done
    
    if [[ -z "$scratch_path" ]]; then
        echo -e "\033[1;31mError:\033[0m Standard scratch mount point not detected."
        echo "Please specify scratch manually: cd /path/to/scratch"
        return 1
    fi
    
    if [[ ! -d "$scratch_path" ]]; then
        mkdir -p "$scratch_path"
        echo "Created scratch folder: $scratch_path"
    fi
    
    # Create symlink in home folder for easy navigation
    if [[ ! -L "$HOME/scratch" ]]; then
        ln -s "$scratch_path" "$HOME/scratch"
        echo "Created symlink: ~/scratch -> $scratch_path"
    fi
    
    cd "$scratch_path"
}

# Check current directory size or quota usage
myquota() {
    echo -e "\033[1;34mChecking disk usage in home directory...\033[0m"
    df -h "$HOME"
    if command -v lfs >/dev/null 2>&1; then
        echo -e "\033[1;34mLustre filesystem quota:\033[0m"
        lfs quota -h . 2>/dev/null || lfs quota -u "$USER" .
    fi
}

# ==========================================
# 🛠️ Environmental Modules & Toolchains
# ==========================================

# Print currently loaded system modules
alias modlist="module list"

# Quick scientific stack loader (adjust modules to match your cluster's inventory)
modload_science() {
    echo -e "\033[1;34mLoading modules for C++, Python, and Julia scientific stack...\033[0m"
    module purge
    module load gcc
    module load openmpi
    module load python
    module load julia 2>/dev/null || echo "Julia module not found. Using system/local installation."
    module list
}

# ==========================================
# 🔒 Interactive session guards (tmux)
# ==========================================
# Highly recommended: auto-launch tmux on login nodes to prevent jobs disconnecting
tmux_guard() {
    if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
        echo -e "\033[1;33mTip:\033[0m To keep your login node sessions alive on network drop, use: \033[1;36mtmux attach || tmux\033[0m"
    fi
}
tmux_guard
