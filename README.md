# Unix Profile Helpers (High-Performance Zsh & HPC Configuration)

A curated and optimized macOS/Unix shell configuration featuring:

- instant shell startup,
- *advanced aliases*,
- helpful utilities,
- a Conda lazy loader,
- and **scientific computing (Slurm/HPC) integrations**.

This profiles are designed to be easily deployed on new machines and clusters, with a modular structure for local and remote configurations. Created with a focus on scientific research workflows, it streamlines development, journaling, and HPC interactions for researchers and developers. Anyway, feel free to fork and customize it for your own needs!

---

## Repository Structure

- **`deploy.sh`**: The automated setup script. This script installs or updates the configuration files, dynamically manages home directory substitutions, audits dependencies, checks Obsidian installations, and deploys configurations to remote HPC supercomputers over secure tunnels (if applicable only).
- **`zshrc`**: The core profile configuration file containing [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) settings, active plugin lists, theme choices (`agnoster`), paths, and the Python/Conda lazy loader. This is a generalized file containing placeholders (`__HOME__`) that one should start with when deploying the profile to a new machine.
- **`common-aliases.zsh`**: An organized, modular aliases and helper functions file for a **local machine**. Defines navigation shortcuts, utility aliases (e.g. `eza`, `bat`, `ripgrep`), C++ compiles, Obsidian helpers, and `mkhelp`. This file is meant to be sourced in the main `zshrc` and can be easily extended with new aliases and functions.
- **`common-hpc.zsh`**: Local machine helper scripts used to manage remote connections, monitor Slurm output logs synced locally (`slog`), and push scripts to cluster workspaces (`qessync`).
- **`common-slurm.zsh`**: A portable, **fully POSIX-compliant** configuration file to copy to the **remote HPC cluster** `.bashrc` or `.zshrc`. It provides job control, colored queues, resource efficiency checking, and scratch disk setup.

---

## Prerequisites & Tools to Install

To get the most out of this configuration, install the following modern CLI tools on a **local machine**. These tools then can be used in the aliases and functions defined in the profile. The deployment on cluster is described in the next section.

### Manual Installation

Most conviniently, one installs the tools manually via Homebrew (see website [https://brew.sh/](https://brew.sh/) for installation instructions). Alternatively, you can install them via their respective package managers or from source.

#### 1. Core Tooling via Homebrew

Ensure [Homebrew](https://brew.sh/) is installed, then run:

```bash
brew install eza bat ripgrep zoxide asdf juliaup
```

#### 2. Oh My Zsh

Install Oh My Zsh:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

#### 3. Zsh Custom Plugins

Clone these custom plugins to your Oh My Zsh folder:

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

---

## Deployment & Setup Instructions

### A. Local Machine (macOS or Linux) Setup

#### Automatic Deployment (Recommended)

Simply execute the included `deploy.sh` script to automatically configure or update your environment:

```bash
chmod +x deploy.sh
./deploy.sh
```

##### **Remote-Only Deployment**

If you wish to configure a remote HPC supercomputer and completely bypass the local profile installer/auditer, simply pass the remote-only flag:

```bash
./deploy.sh --remote-only # or: ./deploy.sh -r
```

##### What the deploy script does for you

1. **System & Prerequisite Auditing**: Inspects your OS (macOS or Linux), checks if Oh My Zsh exists, and lists any missing package dependencies (`eza`, `bat`, `ripgrep`, etc.).
2. **Obsidian Vault Discovery (macOS only)**: Always prompts you for your Obsidian vault name (defaulting to `PhysicsNotes`), then auto-detects its default iCloud path on macOS, falling back to a custom absolute vault path if not found (or if on Linux).
3. **Backup Creation**: Automatically creates time-stamped back-ups (e.g. `.zshrc.backup.YYYYMMDD_HHMMSS`) of any existing config files before writing updates.
4. **Generalization & Substitutions**: Reads the profile files from the repository, dynamically replaces home folder placeholders (`__HOME__`) with your actual home directory, and deploys the files to `~/.zshrc` and `~/.config/zsh/`.
5. **Interactive HPC Deployer (additional)**: Prompts you if you want to deploy to your remote cluster (Slurm) directly.

#### Manual Deployment

If one prefers to copy the files manually, this can be done in a few simple steps:

##### **Zsh Main Profile**

Copy `zshrc` to your home directory. The `zshrc` file contains placeholders (`__HOME__`) that you will need to replace with your actual home directory path after copying:

```bash
cp zshrc ~/.zshrc
```

Open `~/.zshrc` in a text editor and replace all occurrences of `__HOME__` with your actual home directory path (e.g., `/Users/<yourname>` or `/home/<yourname>`).

##### **Local Configurations Folder**

Copy the general aliases and HPC files into a new folder in your home directory. Again, remember to replace the `__HOME__` placeholders in these files with your actual home directory path:

```bash
mkdir -p ~/.config/zsh
cp common-aliases.zsh ~/.config/zsh/common-aliases.zsh
cp common-hpc.zsh ~/.config/zsh/common-hpc.zsh
```

Open `~/.config/zsh/common-aliases.zsh` and `~/.config/zsh/common-hpc.zsh` in a text editor and replace all occurrences of `__HOME__` with your actual home directory path.

##### **Paths Adjustment (CRITICAL)**

Locate and manually replace all occurrences of `__HOME__` in `~/.zshrc` and `~/.config/zsh/common-aliases.zsh` with your actual home directory path (e.g., `/Users/<yourname>` or `/home/<yourname>`).

---

### B. Remote Cluster Setup

One of the workflows in scientific research is to develop code locally and then run large-scale computations on remote HPC clusters. This repository includes a portable Slurm configuration file (`common-slurm.zsh`) that can be easily deployed to your cluster's shell profile, providing you with powerful job management tools and HPC utilities directly in your cluster terminal.

#### Automatic Remote Deployment (via `deploy.sh`)

When you run `./deploy.sh`, you will be prompted if you want to set up remote HPC helpers. If you choose yes:

1. **Interactive Host Input**: Specify your SSH coordinates (e.g., `user@cluster.hpc.edu`).
2. **Automated SSH Key Copying**: The script searches your local SSH configuration for public keys (like `id_rsa.pub` or `id_ed25519.pub`) and securely appends the chosen public key to the remote cluster's `authorized_keys` file to authorize passwordless logins.
3. **Automated Helpers Upload**: Creates remote directories (`~/.config/hpc`) and uploads `common-slurm.zsh` securely to your cluster.
4. **Automated Shell Profile Integration**: Checks the remote cluster shell configuration (`.bashrc` or `.zshrc` depending on what is selected) and safely appends the sourcing block if it isn't already present.

#### Manual Remote Deployment

If one wants to configure the starting point on a cluster manually

##### **Copy Slurm File to Cluster**

Securely copy `common-slurm.zsh` to your remote cluster home directory:

```bash
scp common-slurm.zsh user@cluster-host:~/.config/hpc/common-slurm.sh
```

##### **Sourcing the Helpers**

Open your remote `.bashrc` or `.zshrc` on the cluster and append the following line:

```bash
if [ -f "$HOME/.config/hpc/common-slurm.sh" ]; then
    source "$HOME/.config/hpc/common-slurm.sh"
fi
```

---

## Security Notice & Best Practices

Security and transparency are prioritized in these profile configs:

- **No Hardcoded Credentials**: This repository contains zero hardcoded hostnames, passwords, private keys, or actual usernames.
- **Interactively Prompted Settings**: Any cluster addresses (`user@host`), passwords, or specific directories are prompted dynamically during runtime.
- **Private Key Protection**: The deployment script *never* reads or copies private SSH keys. It only reads public keys (`.pub`) to append to `authorized_keys` on the remote server.
- **Encrypted Shell Session Inputs**: Standard SSH key exchanges and password prompts are handled securely by your system's default OpenSSH binary, assuring no password variables are read, saved, or leaked in plain text.

---

## Command & Helper Description

Here is a thorough description of all available custom commands, shortcuts, and functions defined across these helper profiles:

### 1. General & Navigation Helpers (Local Zsh)

- **`mkhelp [all]`**: The central configuration reference center. Running `mkhelp` prints a clean, colorized reference dashboard showing all active shell plugins, loaded totals, and custom aliases with descriptions. Passing the `all` flag prints the full inventory of all active aliases and functions inside the current shell.
- **`reloadzsh`**: Shorthand for `exec zsh`, which fully reloads your current shell environment without losing your terminal session.
- **`cls`**: Clears the terminal screen (`clear`).
- **`path`**: Prints each directory in your current `$PATH` environment variable on a new line for easy inspection.
- **`mkdirp`**: Shorthand for `mkdir -p` (creates parent directories if needed).
- **`..` / `...` / `....`**: Quick navigation helpers to jump up one, two, or three parent directory levels respectively.
- **`zshconfig`**: Opens your main shell configuration file (`~/.zshrc`) in a text editor (default: TextMate/`mate`).
- **`ohmyzsh`**: Opens the Oh My Zsh configuration directory (`~/.oh-my-zsh`) in a text editor.
- **`mkobsidian`**: Instantly jumps (`cd`) to your active Obsidian notebook vault (defaults to `PhysicsNotes` in iCloud).
- **`mkcontext`**: Directly opens the shared local configurations file (`~/.config/zsh/common-aliases.zsh`) for quick edits.
- **`codes`**: Jumps directly to your local projects workspace folder (`~/Codes`).
- **`pyqusolver`**: Shortcut to navigate directly to `~/Codes/QuantumEigenSolver/pyqusolver`.
- **`qesgen`**: Shortcut to navigate directly to the general Python QES folder `~/Codes/QuantumEigenSolver/pyqusolver/Python/QES/general_python`.
- **`l` / `ll` / `la`**: Directory list helpers. Uses `eza` (sorting folders first, adding Git status metrics for `ll`, and showing hidden files with `la`) when available, and falls back to standard `ls` flags if missing.
- **`cat`**: Automatically overrides `cat` to run `bat --paging=never` to provide beautiful syntax highlighting in the terminal when available.
- **`grep`**: Automatically overrides `grep` to run high-performance `rg` (ripgrep) when available.
- **`mkcd <dir>`**: Creates a new directory and immediately navigates inside it in a single step.
- **`rscp [--rm] [-p PORT] <src> <dst>`**: A highly robust `rsync` copier/mover wrapper. By default, it operates as a copy command with real-time transfer progress, absolute space safety, and SSH port controls. Adding the `--rm` flag converts it into a secure file move that automatically sweeps and deletes empty source directories upon successful transfer.
- **`extract <file>`**: A smart archive extractor. Detects extensions like `.zip`, `.tar.gz`, `.xz`, `.7z`, `.rar`, etc., and automatically runs the appropriate decompression binary with the correct flags.

### 2. Scientific Development & Language Helpers (Local Zsh)

- **`condastat`**: Instantly prints the name of the currently active Anaconda environment in green, along with its active Python version.
- **`juliastat`**: Instantly prints the active Julia compiler version in blue.
- **`armacmp <file.cpp>`**: Automates compilation of C++ files linked to your local Armadillo linear algebra headers. Compiles using highly-optimized flags (`-O3 -std=c++17 -larmadillo`) and prints the compilation status.

### 3. Obsidian Note-Taking Integration (Local macOS)

- **`obsearch "query"`**: Searches through your entire iCloud scientific journal notes (under `PhysicsNotes`) using `ripgrep` directly from the shell terminal, highlighting matches in context.
- **`obnew "note-title"`**: Instantly creates a scientific markdown note in your vault with a pre-configured YAML metadata frontmatter block (title, tags, timestamp) and opens it in your default markdown editor (`mate` or `open`).

### 4. Local HPC & Remote Syncing (Local Zsh)

- **`slog`**: Scans the current directory on your local machine for the latest Slurm log (`slurm-*.out`) and tails it (perfect when mounting cluster workspaces locally).
- **`hpc-sync-to <local_src> <remote_dst>`**: Push scientific codes or datasets to a remote supercomputer path utilizing the highly secure, resume-capable `rscp` wrapper.
- **`qessync`**: High-level shortcut that pushes your local `QuantumEigenSolver` codebase to the cluster workspace.
- **`hpclogin`**: Quick-access shortcut to launch a secure SSH console connection to your configured remote supercomputer (`hpc-cluster`).

### 5. Slurm & Remote HPC Tools (Remote Cluster)

- **`sq`**: Vibrant, color-coded Slurm job queue dashboard. Displays your active/pending jobs, color-coding running jobs in **vibrant Green**, pending/queueing jobs in **vibrant Yellow**, and completing/cancelling jobs in **Red**.
- **`sqall`**: Displays the active Slurm job queue for all users on the supercomputer partition.
- **`sinfo_avail`**: Displays current cluster partition status, node counts, and overall load statistics.
- **`jobeff <job_id>`**: Evaluates CPU and memory resource efficiency for completed jobs (uses `seff` or falls back to custom-formatted `sacct` fields) to prevent over-allocation of resources.
- **`jobtop <job_id>`**: Interactively runs `htop` inside your running Slurm job node for real-time memory and CPU thread profiling.
- **`salloc_quick [cores] [walltime] [partition]`**: Grab a computing node on the fly for interactive debugging (avoids slowing down cluster login nodes). Defaults to `4` cores and `2` hours if unspecified.
- **`scanc <job_id>`**: Shorthand to cancel a specific Slurm job.
- **`scancall`**: Immediately cancels all of your active and pending Slurm jobs.
- **`slog`**: Tails the latest `slurm-*.out` log file generated in the remote directory.
- **`mkscratch`**: Automatically locates cluster high-speed parallel scratch storage space (e.g., Lustre/GPFS under `/scratch/$USER` or `/work/$USER`), creates the user workspace if needed, and deploys a symbolic link (`~/scratch`) in your home folder for instant navigation.
- **`myquota`**: Rapidly displays home directory disk utilization and Lustre filesystem quotas.
- **`modlist`**: Quick shorthand for `module list` to view active environment configurations.
- **`modload_science`**: Performs a clean system environment purge and automatically loads a standard GCC, OpenMPI, Python, and Julia scientific computing stack.
- **`tmux_guard`**: A protective background daemon that automatically advises attaching `tmux` on cluster login sessions to safeguard against connection dropouts.

---

## Scientific HPC & Note-Taking Workflow Guide

This profile is designed to allow easier scientific research workflow using the local machine, Obsidian journal (assumingly - it should be installed and configured), and remote supercomputers:

### 1. Local C++ and Python Solver Development

Those methods are meant to be used on the local machine, where one can easily check the compilations. Currently, designed for:

- C++ solvers linked with Armadillo (a high-quality linear algebra library),
- Python scripts using Conda environments.

The HPC cluster can be used for large-scale runs as well as interactive debugging sessions.

It includes:

- Write your high-level solvers locally.
- Compile C++ files linked with Armadillo instantly:

    ```bash
    armacmp solver.cpp
    ```

- Use the active environment diagnostic commands to verify compilers:

    ```bash
    condastat
    juliastat
    ```

---

### 2. Rapid Obsidian Journaling

- Keep a diary of *physics, math, and computer science* notes inside Obsidian. Search through your journal from the command-line using `ripgrep`:

```bash
obsearch "Schrodinger equation"
```

- Create a new scientific markdown note with pre-formatted YAML metadata frontmatter:

```bash
obnew "quantum eigen solvers in d-dimensional space"
```

### 3. Synchronization & Code Deployment

- Use the secure, robust rsync wrapper `rscp` to push local codes up to the cluster scratch directory:

```bash
qessync
```

### 4. Interactive Debugging on Cluster Nodes

Never compile or run long test scripts directly on the cluster login nodes (this can slow down the frontend for all users). Instead, request a quick interactive computing session on a worker node:

```bash
salloc_quick 8 01:00:00 # Requests 8 cores for 1 hour
# or 
salloc_quick 16 00:30:00 # Requests 16 cores for 30 minutes
```

### 5. High-Speed Parallel Disk Workflows

HPC nodes have high-speed parallel file systems (like Lustre) mounted on `/scratch` or `/work`. Use the `mkscratch` command on the cluster to navigate directly to high-speed scratch space, which auto-creates a symbolic link (`~/scratch`) in the home folder:

```bash
mkscratch
```

### 6. Resource Audits

After a job completes, review its CPU/Memory usage efficiency so you can tune future Slurm submission headers (this reduces queue waiting times!):

```bash
jobeff <job_id>
```
