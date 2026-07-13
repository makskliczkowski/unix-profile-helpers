# Local HPC and Slurm workspace helpers for macOS and Linux.

: "${UPH_ZSH_CONFIG_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"

# View the tail of the latest Slurm output file in the current directory (useful if cluster folders are mounted/synced)
slog() {
    local latest_log
    latest_log=$(ls -t slurm-*.out 2>/dev/null | head -n 1)
    if [[ -n "$latest_log" ]]; then
        echo -e "\033[1;34mTailing log: $latest_log\033[0m"
        tail -f "$latest_log"
    else
        echo "No slurm-*.out files found in the current directory."
        return 1
    fi
}

# Sync local scientific codes to the remote HPC cluster scratch/home
# Uses your portable, robust 'rscp' wrapper defined in common-aliases.zsh
hpc-sync-to() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: hpc-sync-to <local_src_path> <remote_dst_user@host:path>"
        return 1
    fi
    rscp "$1" "$2"
}

# Optional QuantumEigenSolver sync shortcut. Configure UPH_QES_REMOTE and enable
# the solver paths in the machine-local Zsh config before using it.
qessync() {
    if [[ ${UPH_ENABLE_SOLVER_PATHS:-false} != true || -z ${QES_PYQUSOLVER_DIR:-} ]]; then
        print -u2 "qessync: enable QuantumEigenSolver paths in $UPH_ZSH_CONFIG_DIR/local.zsh first."
        return 1
    fi
    if [[ -z ${UPH_QES_REMOTE:-} ]]; then
        print -u2 "qessync: set UPH_QES_REMOTE in $UPH_ZSH_CONFIG_DIR/local.zsh."
        return 1
    fi
    rscp "$QES_PYQUSOLVER_DIR/" "$UPH_QES_REMOTE"
}

# Optional quick login. UPH_HPC_HOST may be an SSH config host or user@host.
hpclogin() {
    if [[ -z ${UPH_HPC_HOST:-} ]]; then
        print -u2 "hpclogin: set UPH_HPC_HOST in $UPH_ZSH_CONFIG_DIR/local.zsh."
        return 1
    fi
    ssh "$UPH_HPC_HOST" "$@"
}
