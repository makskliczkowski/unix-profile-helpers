# Local HPC & Slurm Workspace Integration Helpers
# Designed for use on your local machine (macOS) to manage HPC resources and code syncs.

# View the tail of the latest Slurm output file in the current directory (useful if cluster folders are mounted/synced)
slog() {
    local latest_log=$(ls -t slurm-*.out 2>/dev/null | head -n 1)
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

# Shortcut to sync QuantumEigenSolver code to the cluster
# (Edit the remote address below to match your actual cluster logins)
alias qessync="rscp ~/Codes/QuantumEigenSolver/pyqusolver/ cluster-login-placeholder:~/Codes/QuantumEigenSolver/pyqusolver/"

# Quick login to cluster (Configure 'hpc-cluster' in ~/.ssh/config for passwordless key-based logins!)
alias hpclogin="ssh hpc-cluster"
