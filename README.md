# Unix Profile Helpers (High-Performance Zsh & HPC Configuration)

A curated, highly-optimized macOS/Unix shell configuration featuring instant shell startup, advanced alias systems, helpful utilities, a Conda lazy loader, and **first-class scientific computing (Slurm/HPC) integrations**.

---

## 🚀 Performance Overview

On macOS, sourcing large environment manager initialization scripts (such as Anaconda or Miniforge) synchronously on shell startup is a major bottleneck—often adding **1.4s to 2.0s** of latency per terminal tab because of compiler wrapper checks (`_tc_activation`). 

This setup resolves that issue by utilizing a **custom lazy loader for Conda**. Shell startup time is reduced to **~0.15s - 0.25s (an 11x speedup)**, while the `conda` command remains fully functional and automatically initializes the environment the first time it is called.

---

## 📁 Repository Structure

*   **`zshrc`**: The core profile configuration file containing Oh My Zsh settings, active plugin lists, theme choices (`agnoster`), paths, and the Python/Conda lazy loader.
*   **`common-aliases.zsh`**: A highly organized, modular aliases and helper functions file for your **local machine**. Defines navigation shortcuts, modern utility aliases (e.g. `eza`, `bat`, `ripgrep`), C++ compiles, Obsidian helpers, and `mkhelp`.
*   **`common-hpc.zsh`**: Local machine helper scripts used to manage remote connections, monitor Slurm output logs synced locally (`slog`), and push scripts to cluster workspaces (`qessync`).
*   **`common-slurm.zsh`**: A portable, **fully POSIX-compliant** configuration file to copy to your **remote HPC cluster** `.bashrc` or `.zshrc`. It provides job control, colored queues, resource efficiency checking, and scratch disk setup.

---

## 🔬 Scientific HPC & Note-Taking Workflow Guide

This profile is designed to facilitate a state-of-the-art scientific research workflow spanning your local machine, Obsidian journal, and remote supercomputers:

### 1. Local C++ and Python Solver Development
*   Write your high-level solvers locally. 
*   Compile C++ files linked with Armadillo instantly:
    ```bash
    armacmp solver.cpp
    ```
*   Use the active environment diagnostic commands to verify compilers:
    ```bash
    condastat
    juliastat
    ```

### 2. Rapid Obsidian Journaling
*   Keep a mathematical diary of your physics notes inside Obsidian. Search your journal from the command-line using `ripgrep`:
    ```bash
    obsearch "Schrodinger equation"
    ```
*   Create a new scientific markdown note with pre-formatted YAML metadata frontmatter:
    ```bash
    obnew "quantum eigen solvers in d-dimensional space"
    ```

### 3. Synchronization & Code Deployment
*   Use the secure, robust rsync wrapper `rscp` to push local codes up to the cluster scratch directory:
    ```bash
    qessync
    ```

### 4. Interactive Debugging on Cluster Nodes
*   Never compile or run long test scripts directly on the cluster login nodes (this can slow down the frontend for all users). Instead, request a quick interactive computing session on a worker node:
    ```bash
    salloc_quick 8 01:00:00   # Requests 8 cores for 1 hour
    ```

### 5. High-Speed Parallel Disk Workflows
*   HPC nodes have high-speed parallel file systems (like Lustre) mounted on `/scratch` or `/work`. Use the `mkscratch` command on the cluster to navigate directly to your high-speed scratch space, which auto-creates a symbolic link (`~/scratch`) in your home folder:
    ```bash
    mkscratch
    ```

### 6. Resource Audits
*   After a job completes, review its CPU/Memory usage efficiency so you can tune future Slurm submission headers (this reduces queue waiting times!):
    ```bash
    jobeff <job_id>
    ```

---

## 🛠️ Prerequisites & Tools to Install

To get the most out of this configuration, install the following modern CLI tools on your **local machine**.

### 1. Core Tooling via Homebrew
Ensure [Homebrew](https://brew.sh/) is installed, then run:
```bash
brew install eza bat ripgrep zoxide asdf juliaup
```

### 2. Oh My Zsh
Install Oh My Zsh:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 3. Zsh Custom Plugins
Clone these custom plugins to your Oh My Zsh folder:
```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

---

## ⚙️ Deployment & Setup Instructions

### A. Local Machine (macOS) Setup
1. **Zsh Main Profile**: Copy the `zshrc` file in this repository to your home directory:
   ```bash
   cp zshrc ~/.zshrc
   ```
2. **Local Configurations Folder**: Copy the general aliases and HPC files:
   ```bash
   mkdir -p ~/.config/zsh
   cp common-aliases.zsh ~/.config/zsh/common-aliases.zsh
   cp common-hpc.zsh ~/.config/zsh/common-hpc.zsh
   ```
3. **Paths Adjustment (CRITICAL)**: Locate and replace `/Users/makskliczkowski` in `~/.zshrc` and `~/.config/zsh/common-aliases.zsh` with your new username or `$HOME`. Update compiling/Julia paths to match your hardware layout.

### B. Remote Cluster Setup
1. **Copy Slurm File to Cluster**: Securely copy `common-slurm.zsh` to your remote cluster home directory:
   ```bash
   scp common-slurm.zsh user@cluster-host:~/.config/hpc/common-slurm.sh
   ```
2. **Sourcing the Helpers**: Open your remote `.bashrc` or `.zshrc` on the cluster and append the following line:
   ```bash
   if [ -f "$HOME/.config/hpc/common-slurm.sh" ]; then
       source "$HOME/.config/hpc/common-slurm.sh"
   fi
   ```

---

## 💡 Command Quick-Reference

### Local Commands
*   `mkhelp`: Live-shell command and alias reference sheet.
*   `rscp [--rm]`: Safe, high-speed `rsync` move/copy with real-time transfer progress.
*   `obsearch "query"`: Full-text ripgrep of your Obsidian science journal.
*   `obnew "title"`: Autogenerate note with YAML headers and scientific tags.
*   `armacmp filename.cpp`: Compiles C++ script linked with local Armadillo libraries.
*   `qessync`: Sync your Python eigen solver code directly to your remote supercomputer.
*   `hpclogin`: Instant SSH cluster console.

### Remote Cluster Commands
*   `sq`: Beautiful, colored job queue specifically for your jobs.
*   `salloc_quick <cores> <time>`: Grab a computational node on the fly for interactive debugging.
*   `jobeff <job_id>`: Check CPU/Memory resource consumption efficiency for tuning Slurm scripts.
*   `mkscratch`: Instantly jumps to your high-speed scratch space and sets up symbolic linking.
*   `modload_science`: Clean environment purge and loading of standard GCC, MPI, Python configurations.
