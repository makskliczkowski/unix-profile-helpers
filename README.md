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

Here is a thorough description of the custom commands and aliases defined in these helper profiles:

### 1. General & Navigation Helpers (Local)

- `mkhelp`: The central reference manager. Typing `mkhelp` prints a reference card showing all active shell plugins, loaded totals, and custom aliases with clear descriptions.
- `rscp [--rm] <src> <dst>`: A safe `rsync` mover and copier. By default, it acts as a copy command with high-performance real-time progress indicators. Adding the `--rm` flag converts the command into a robust move, safely cleaning empty folders after completion.
- `extract <file>`: A universal archive extractor. Easily extracts `.zip`, `.tar.gz`, `.xz`, `.7z`, `.rar`, and more, without needing to remember distinct command flags.
- `mkcd <dir>`: Creates a directory and immediately navigates into it.
- `condastat` / `juliastat`: Rapid diagnosis tools showing active Conda environments and active Julia versions.
- `armacmp filename.cpp`: Automatically compiles C++ files linked with your local Armadillo linear algebra headers using highly optimized flags (`-O3`).

### 2. Obsidian note-taking commands (Local)

- `obsearch "query"`: Searches inside your iCloud PhysicsNotes note journal using `ripgrep` directly from the shell terminal.
- `obnew "note-title"`: Instantly creates a scientific markdown note in your vault with a pre-configured YAML frontmatter metadata block (title, timestamp, tagging structure) and opens it in your default markdown viewer.

### 3. Local HPC management (Local)

- `slog`: Locally scans for the latest Slurm log (`slurm-*.out`) in the current directory and tails its output.
- `qessync`: High-level sync shortcut that pushes your local Python solver solver folder up to the cluster.
- `hpclogin`: Instant SSH connection shortcut to your cluster console.

### 4. Slurm & Remote HPC tools (Remote Cluster)

- `sq`: Color-coded Slurm queue utility. Shows only your running/pending jobs, coloring them dynamically so you see immediately what is running (Green) or pending (Yellow).
- `salloc_quick <cores> <time>`: Grab a computing node on the fly for interactive testing (keeps login nodes from slowing down).
- `jobeff <job_id>`: Check CPU and RAM resource efficiency for completed jobs to prevent over-allocation.
- `jobtop <job_id>`: Interactively runs `htop` inside your running job node.
- `mkscratch`: Jumps directly to high-speed scratch spaces (Lustre/Parallel, e.g., `/scratch/$USER` or `/work/$USER`), creates the folder structure if needed, and sets up a symlink (`~/scratch`) in your home folder for quick navigation.
- `modload_science`: Clean environment purge and loading of standard GCC, MPI, Python configurations.

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
