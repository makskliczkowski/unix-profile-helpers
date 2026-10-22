# Example cluster profile. Copy to <cluster>.sh and edit.
# Only assignments belong here; do not run commands in a profile.

HPC_NAME="example"
HPC_DESCRIPTION="Example Slurm cluster"

# Connection. HPC_SSH_HOST is either an ~/.ssh/config alias or a hostname.
# The optional fields below are added on top of that alias when set.
HPC_SSH_HOST="cluster"
# HPC_SSH_USER="username"          # main (login) account
# HPC_SSH_PORT="22"
# HPC_SSH_PROXYJUMP="bastion"
# HPC_SSH_IDENTITY="$HOME/.ssh/id_ed25519"
# HPC_SSH_OPTIONS=("-o" "ServerAliveInterval=30")

# Scheduling. The Slurm account is the project/billing account, which is
# normally different from the login account above.
HPC_SLURM_ACCOUNT="project-account"
HPC_SLURM_PARTITION="batch"
# HPC_SLURM_QOS="normal"
HPC_SLURM_TIME="08:00:00"
HPC_SLURM_MEM="64G"
HPC_SLURM_CPUS="8"
HPC_SLURM_GPUS="1"
# gres | gpus | gpus-per-node
HPC_SLURM_GPU_STYLE="gres"
HPC_SLURM_NODES="1"
# HPC_SLURM_MAIL="me@example.org"  # --mail-user, with --mail-type=END,FAIL
HPC_SLURM_EXTRA=()

# Environment, applied in this order: INIT, purge, modules, conda, sources,
# vars, pre. HPC_ENV_INIT is needed when module is a shell function.
HPC_ENV_INIT=""
HPC_ENV_PURGE="true"
# Optional conda environment (name or absolute prefix). Activated after modules.
HPC_ENV_CONDA=""
HPC_ENV_MODULES=("Python/3.11.3" "CUDA/12.1")
# Files to source after the modules, for example a virtualenv or conda init.
HPC_ENV_SOURCE=()
# KEY=VALUE, exported only by hpc_env_apply or shub terminal startup. $VAR,
# ${VAR} and a leading ~ expand; command substitution does not.
HPC_ENV_VARS=("OMP_NUM_THREADS=8")
HPC_ENV_PRE=()

# Optional shell/scratch settings used by the remote helpers.
# HPC_SCRATCH_DIR="/scratch/$USER"
# HPC_QUOTA_GROUP="project-account"
# HPC_SHELL="/bin/bash"

# Defaults used by shub and the shell helpers. Use "~" for the remote home;
# "$HOME" here would expand to the local home when the profile is read.
HPC_WORKDIR="~"
HPC_PYTHON="python3"
HPC_JUPYTER_CMD="jupyter lab"
HPC_JUPYTER_EXTRA=("--ServerApp.open_browser=False")
# HPC_JUPYTER_IP="0.0.0.0"         # bind address on the compute node
# HPC_JUPYTER_PORT="0"             # 0 picks a free port

# shub terminal: whether it sources ~/.bashrc (default true), and extra files
# sourced after the environment is applied.
# HPC_TERM_BASHRC="true"
# HPC_TERM_SOURCE=("~/.config/hpc/extra.sh")

HPC_NOTES="
Replace this paragraph with cluster-specific notes: partition names,
module versions, filesystem layout, and known quirks.
"
