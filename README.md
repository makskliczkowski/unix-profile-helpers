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
- **`local.zsh.example`**: A template for machine-specific paths and optional plugin settings. It is installed as `~/.config/zsh/local.zsh` once and preserved by later deployments.
- **`common-aliases.zsh`**: An organized, modular aliases and helper functions file for a **local machine**. Defines navigation shortcuts, utility aliases (e.g. `eza`, `bat`, `ripgrep`), C++ compiles, Obsidian helpers, and `mkhelp`. This file is meant to be sourced in the main `zshrc` and can be easily extended with new aliases and functions.
- **`common-hpc.zsh`**: Local machine helper scripts used to manage remote connections, monitor Slurm output logs synced locally (`slog`), and push scripts to cluster workspaces (`qessync`).
- **`common-slurm.zsh`**: A portable Bash/Zsh configuration file for a **remote HPC cluster**. It provides job control, interactive allocations, module profiles, resource checks, and Lustre/scratch discovery.

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

Machine-specific values should be placed in `~/.config/zsh/local.zsh`, for example:

```zsh
UPH_ENABLE_SOLVER_PATHS=false
typeset -ga UPH_EXTRA_PLUGINS=(kubectl)
```

Solver package exports are enabled by default. Set `UPH_ENABLE_SOLVER_PATHS=false` to omit `QES_PYPATH`, `QES_PYPATH_GEN_PYTHON`, and `QES_SLURMPATH`, or define individual paths in `local.zsh` to override their defaults. Optional library locations such as `ARMADILLO_INCL_DIR` have no shared default and should only be added to `local.zsh` on machines where they are installed.

The deployer creates this file only if it is missing, so repository updates do not overwrite local paths. Keep API keys out of the profile and load them from a credential manager or another appropriately protected mechanism.

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
3. **Validated Helpers Upload**: Uploads to a temporary file, validates Bash and Zsh syntax remotely, backs up the previous helper, and only then activates the update.
4. **Per-Cluster Settings**: Creates `~/.config/hpc/local.sh` once for cluster-specific partitions, accounts, scratch paths, and exact module names. Later deployments preserve it.
5. **Automated Shell Profile Integration**: Checks the remote cluster shell configuration (`.bashrc` or `.zshrc` depending on what is selected), appends the sourcing block if needed, and verifies that `inter` and `hpchelp` load.

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

- **`cls`**: Clears the terminal screen (`clear`).
- **`..` / `...` / `....`**: Quick navigation helpers to jump up one, two, or three parent directory levels, respectively.
- **`cat`**: Automatically overrides `cat` to run `bat --paging=never` to provide beautiful syntax highlighting in the terminal when available.
- **`codes`**: Jumps directly to local projects workspace folder (`~/Codes`) (if it exists).
- **`l` / `ll` / `la`**: Directory list helpers. Uses `eza` (sorting folders first, adding Git status metrics for `ll`, and showing hidden files with `la`) when available, and falls back to standard `ls` flags if missing.
- **`grep`**: Automatically overrides `grep` to run high-performance `rg` (ripgrep) when available.
- **`mkcd <dir>`**: Creates a new directory and immediately navigates inside it in a single step.
- **`mkcontext`**: Directly opens the shared local configurations file (`~/.config/zsh/common-aliases.zsh`) for quick edits.
- **`mkhelp [all]`**: The central configuration reference center. Running `mkhelp` prints a clean, colorized reference dashboard showing all active shell plugins, loaded totals, and custom aliases with descriptions. Passing the `all` flag prints the full inventory of all active aliases and functions inside the current shell.
- **`mkdirp`**: Shorthand for `mkdir -p` (creates parent directories if needed).
- **`mkobsidian`**: Instantly jumps (`cd`) to your active Obsidian notebook vault (defaults to `PhysicsNotes` in iCloud).
- **`ohmyzsh`**: Opens the Oh My Zsh configuration directory (`~/.oh-my-zsh`) in a text editor.
- **`path`**: Prints each directory in your current `$PATH` environment variable on a new line for easy inspection.
- **`pyqusolver`**: Shortcut to navigate directly to `~/Codes/QuantumEigenSolver/pyqusolver` (if it exists).
- **`qesgen`**: Shortcut to navigate directly to the general Python QES folder `~/Codes/QuantumEigenSolver/pyqusolver/Python/QES/general_python` (if it exists).
- **`reloadzsh`**: Shorthand for `exec zsh`, which fully reloads your current shell environment without losing your terminal session.
- **`rscp [--rm] [-p PORT] <src> <dst>`**: A highly robust `rsync` copier/mover wrapper. By default, it operates as a copy command with real-time transfer progress, absolute space safety, and SSH port controls. Adding the `--rm` flag converts it into a secure file move that automatically sweeps and deletes empty source directories upon successful transfer.
- **`extract <file>`**: A smart archive extractor. Detects extensions like `.zip`, `.tar.gz`, `.xz`, `.7z`, `.rar`, etc., and automatically runs the appropriate decompression binary with the correct flags.
- **`zshconfig`**: Opens your main shell configuration file (`~/.zshrc`) in a text editor (default: TextMate/`mate`).

### 2. Scientific Development & Language Helpers (Local Zsh)

- **`condastat`**: Instantly prints the name of the currently active Anaconda environment in green, along with its active Python version.
- **`juliastat`**: Instantly prints the active Julia compiler version in blue.
- **`armacmp <file.cpp>`**: Automates compilation of C++ files linked to your local Armadillo linear algebra headers. Compiles using highly-optimized flags (`-O3 -std=c++17 -larmadillo`) and prints the compilation status.

### 3. Obsidian Note-Taking Integration (Local macOS)

- **`obsearch "query"`**: Searches through your entire iCloud scientific journal notes (under `PhysicsNotes`) using `ripgrep` directly from the shell terminal, highlighting matches in context.
- **`obnew "note-title"`**: Instantly creates a scientific markdown note in your vault with a pre-configured YAML metadata frontmatter block (title, tags, timestamp) and opens it in your default markdown editor (`mate` or `open`).

### 4. Local HPC & Remote Syncing (Local Zsh)

- **`slog`**: Scans the current directory on local machine for the latest Slurm log (`slurm-*.out`) and tails it (perfect when mounting cluster workspaces locally).
- **`hpc-sync-to <local_src> <remote_dst>`**: Push codes or datasets to a remote supercomputer path utilizing the highly secure, resume-capable `rscp` wrapper.
- **`qessync`**: High-level shortcut that pushes your local `QuantumEigenSolver` codebase to the cluster workspace.
- **`hpclogin`**: Quick-access shortcut to launch a secure SSH console connection to your configured remote supercomputer (`hpc-cluster`).

### 5. Slurm & Remote HPC Tools (Remote Cluster)

- **`hpchelp`**: Prints the complete runtime reference for remote job, storage, and module helpers.
- **`hpcdoctor`**: Reports whether Slurm commands, environment modules, Lustre tools, and a scratch directory are visible in the current shell.
- **`sq`**: Custom detailed Slurm job queue view. Displays your jobs including array IDs, partition, job name, maximum allocated CPUs, requested memory limits, walltime used/left, scheduling pending reason, compact job state, and active working directory.
- **`sqr`**: Shorthand for `sq` restricted strictly to your currently running jobs.
- **`sqn`**: Instantly prints the combined count of your active (running + pending) jobs.
- **`sqnr`**: Instantly prints the count of your currently running jobs.
- **`sac`**: Comprehensive accounting check since midnight showing JobID, JobName, partition, cores, node counts, average CPU, total CPU, maximum RSS (RAM used), requested memory, average RSS, average VM size, start time, elapsed time, job state, and exit code.
- **`sqc`**: Color-coded active queue dashboard. Shows the jobs, color-coding running jobs in **vibrant Green**, pending/queueing jobs in **vibrant Yellow**, and completing/cancelling jobs in **Red**.
- **`sqall`**: Displays the active Slurm job queue for all users on the supercomputer partition.
- **`sqpd`**: Displays your pending jobs only, including the exact wait/scheduling reason codes.
- **`jobnodes`**: Quick mapping of active job IDs to their allocated compute nodes.
- **`sque` / `sqh`**: Quick shorthands for standard `squeue` and headers-free `squeue` outputs.
- **`sprio_me`**: Displays your current scheduling priority coefficients across active partitions.
- **`jobeff <job_id>`**: Evaluates CPU and memory resource efficiency for completed jobs (uses `seff` or falls back to custom-formatted `sacct` fields) to prevent over-allocation of resources.
- **`jobtop <job_id>`**: Interactively runs `htop` inside your running Slurm job node for real-time memory and CPU thread profiling.
- **`inter [options]` / `sub-interactive [options]`**: Requests an interactive login shell using PC2's documented `srun ... --pty shell` pattern. Supports CPU (`-c`), time (`-t`), memory (`-m`), partition (`-p`), account (`-A`), QoS (`-q`), GPU GRES (`-g`), and shell (`-s`). Run `inter -h` for details.
- **`inter_gpu [count]`**: Requests a Noctua 2 development GPU session on `dgx` with QoS `devel`, A100 GRES, 16 CPU cores per GPU, and PC2's GPU-count-dependent time limit.
- **`salloc_quick [cores] [walltime] [partition]`**: Grab a computing node on the fly for interactive debugging (avoids slowing down cluster login nodes). Defaults to `4` cores and `2` hours if unspecified.
- **`mkslurm <script_name.sh>`**: Rapidly generates a robust, production-ready Slurm batch submission script template populated with highly-commented `#SBATCH` configurations, modular clean purge layers, and custom execution markers.
- **`scanc <job_id>`**: Shorthand to cancel a specific Slurm job.
- **`scancall`**: Immediately cancels all of your active and pending Slurm jobs.
- **`slog`**: Tails the latest `slurm-*.out` log file generated in the remote directory.
- **`lustreinfo` / `hpc_find_scratch`**: Lists Lustre mounts and reports the selected user scratch directory. Detection uses configured paths, common locations, and mounted Lustre filesystems.
- **`mkscratch [path]`**: Creates or selects a user scratch directory, updates `~/scratch`, and enters it. Set `UPH_SCRATCH_DIR` when a cluster uses a project-specific layout.
- **`myquota [path]`**: Displays filesystem utilization and uses `lfs quota` on Lustre or standard `quota` as a fallback.
- **`modpurge` / `modlist` / `modavail`**: Purges, lists, or searches the environment-module stack.
- **`moddefaults` / `modoverview` / `modshow` / `modspider` / `modkeyword`**: Exposes PC2/Lmod default-module, overview, metadata, and search operations.
- **`modreset` / `modunload` / `modswap` / `moduse` / `modhelp`**: Resets or modifies the active module environment and search path.
- **`software_find <query>`**: Uses a site-provided `find_module` or `find_modules` command when available, with Lmod search as a fallback.
- **`modload <profiles...>`**: Loads one or more `cpp`, `fortran`, `mpi`, `hdf5`, `python`, `cmake`, `math` (BLAS/LAPACK), `boost`, `netcdf`, or combined `science` profiles.
- **`modload_cpp` / `modload_fortran` / `modload_hdf5` / `modload_python` / `modload_science`**: Convenience wrappers for common build and runtime environments.
- **`tmux_guard`**: Advises using `tmux` for remote interactive sessions when appropriate.

Cluster module names are not standardized. Set exact names in `~/.config/hpc/local.sh` when the defaults do not match:

```sh
UPH_SLURM_PARTITION=normal
UPH_SLURM_ACCOUNT=my-project
UPH_MODULE_SLURM=slurm
UPH_SCRATCH_DIR=/path/to/project/scratch
UPH_MODULE_COMPILER=GCC/13.2.0
UPH_MODULE_MPI=OpenMPI/4.1.6
UPH_MODULE_HDF5=HDF5/1.14.3
UPH_MODULE_PYTHON=Python/3.11
UPH_MODULE_JULIA=Julia/1.11
UPH_MODULE_CONTAINER=Apptainer
UPH_MODULE_BLAS=OpenBLAS/0.3.26
UPH_MODULE_BOOST=Boost/1.84.0
UPH_MODULE_NETCDF=netCDF/4.9.2
```

#### Lustre and Scratch Configuration

`lustreinfo` reports two different facts:

```text
Detected Lustre mounts:
/scratch
Lustre client:
lfs 2.14.0_ddn240
```

- `lfs 2.14.0_ddn240` means the DDN Lustre client tools are installed. It does **not** identify your personal scratch directory.
- `/scratch` is the Lustre mount point visible on the login node. It does **not** imply that `/scratch/$USER` exists or that users may create directories directly below `/scratch`.

Clusters commonly organize Lustre storage by project, account, group, or allocation. On PC2, `$PC2PFS` is the base for temporary parallel project data and the usable path is normally `$PC2PFS/<project-acronym>`, not `/scratch/$USER`. Examples include:

```text
/scratch/$USER
/scratch/users/$USER
/scratch/<project>/$USER
/scratch/<account>/$USER
/scratch/<project>
```

The helper automatically accepts configured paths, `$SCRATCH`, common user paths, and writable user directories under detected Lustre mounts. It intentionally does not choose an arbitrary project directory.

If `mkscratch` reports:

```text
No user scratch directory was detected.
Set UPH_SCRATCH_DIR in your remote shell profile, then run mkscratch.
Detected Lustre mounts:
  /scratch
```

first find the path assigned by the cluster:

```bash
echo "$SCRATCH"
echo "$PC2PFS"
pc2info
pc2projects
ls -ld /scratch "/scratch/$USER" 2>/dev/null
find /scratch -maxdepth 3 -type d -user "$USER" 2>/dev/null
pc2status
```

Consult the cluster documentation or support team if these commands do not identify the allocation. Do not create a guessed project directory.

Once the correct path is known, add it to the preserved remote configuration:

```bash
cat >> "$HOME/.config/hpc/local.sh" <<'EOF'
UPH_PC2_PROJECT="hpc-prf-<project>"
UPH_SCRATCH_DIR="$PC2PFS/$UPH_PC2_PROJECT"
EOF
. "$HOME/.config/hpc/common-slurm.sh"
mkscratch
```

Alternatively, test a path once without changing the configuration:

```bash
mkscratch "$PC2PFS/hpc-prf-<project>"
```

On success, `mkscratch`:

1. Verifies the directory exists, or creates it only when its parent is writable.
2. Creates or updates `~/scratch` as a symbolic link.
3. Changes the current directory to the selected scratch path.

Use these diagnostics afterwards:

```bash
hpc_find_scratch
readlink -f "$HOME/scratch"
myquota
hpcdoctor
```

On Noctua, Lustre quotas are normally assigned to the Unix group corresponding to a project. After setting `UPH_PC2_PROJECT`, `myquota` uses:

```bash
lfs quota -h -g "$UPH_PC2_PROJECT" "$PC2PFS"
```

#### Module Loading Behavior

The module helpers use the cluster's existing Environment Modules or Lmod installation. They do not assume a particular cluster naming scheme and do not install compilers, Python, MPI, HDF5, or other libraries.

`modload` processes each requested profile as follows:

1. Initializes `module` from common system initialization scripts if necessary.
2. Converts the profile to a generic variable such as `hdf5` to `UPH_MODULE_HDF5`.
3. Tries the exact module name stored in that environment variable.
4. For built-in profiles only, tries a short list of generic names such as `HDF5` or `hdf5`.
5. Stops at the first candidate that loads successfully.
6. Runs `module list` after processing all requested profiles.
7. Returns a nonzero status if any requested profile could not be loaded.

Set a mapping in the current shell:

```bash
modset hdf5 HDF5/1.14.3
modset cpp GCC/13.2.0
modset python Python/3.11
```

Persist it in `~/.config/hpc/local.sh`:

```bash
modset --persist hdf5 HDF5/1.14.3
modset -p cpp GCC/13.2.0
```

Inspect or remove mappings:

```bash
modget
modget hdf5
modunset hdf5
modunset --persist hdf5
```

Profiles are normalized to `UPH_MODULE_<PROFILE>`. Hyphens become underscores and names become uppercase. Related aliases share a canonical variable:

```text
cpp, cxx, fortran       -> UPH_MODULE_COMPILER
math, blas, lapack      -> UPH_MODULE_BLAS
container, apptainer,
singularity             -> UPH_MODULE_CONTAINER
```

Arbitrary custom profiles require no library changes:

```bash
modset --persist petsc PETSc/3.21.5
modset --persist cuda CUDA/12.4
modset --persist fftw FFTW/3.3.10

modload petsc cuda fftw
```

The equivalent direct configuration is:

```sh
export UPH_MODULE_PETSC="PETSc/3.21.5"
export UPH_MODULE_CUDA="CUDA/12.4"
export UPH_MODULE_FFTW="FFTW/3.3.10"
```

This environment-variable pass-through is the preferred way to adapt the generic library to any cluster.

The profiles perform these loads:

| Profile | Modules attempted |
| --- | --- |
| `cpp`, `fortran` | Compiler: configured compiler, GCC, or Intel alternatives |
| `mpi` | MPI implementation: configured MPI, OpenMPI, generic MPI, or Intel MPI |
| `hdf5` | Serial or parallel HDF5 module |
| `python` | Python, Anaconda, or Miniconda |
| `julia` | Configured Julia module, then generic Julia names |
| `container` | Configured container module, then Apptainer or Singularity |
| `cmake` | CMake |
| `math` | OpenBLAS, FlexiBLAS, BLAS/LAPACK, or Intel MKL |
| `boost` | Boost |
| `netcdf` | NetCDF |
| `science` | Compiler, MPI, HDF5, math libraries, Python, and CMake |

Convenience commands expand to:

```text
modload_cpp       -> modload cpp cmake
modload_fortran   -> modload fortran cmake
modload_hdf5      -> modload cpp mpi hdf5
modload_python    -> modload python
modload_julia     -> modload julia
modload_container -> modload container
modload_science   -> modload science
```

Search before loading when the exact site module name is unknown:

```bash
software_find HDF5
software_find Python
modoverview
modspider HDF5
modkeyword compiler mpi
modshow lang/Python
```

`software_find` uses a site-provided `find_module`/`find_modules` command when available and falls back to Lmod `module spider` or `module keyword`.

For example, a PC2 installation may use qualified names:

```bash
modset --persist python lang/Python/3.11.5
modset --persist julia lang/JuliaHPC
modset --persist container system/Apptainer
```

Because module names and dependency trees differ between clusters, inspect available versions before setting overrides:

```bash
modavail GCC
modavail HDF5
modavail Python
module spider HDF5 2>/dev/null   # Lmod clusters
```

Then configure exact, compatible names in `~/.config/hpc/local.sh`:

```sh
UPH_MODULE_COMPILER="GCC/13.2.0"
UPH_MODULE_MPI="OpenMPI/4.1.6-GCC-13.2.0"
UPH_MODULE_HDF5="HDF5/1.14.3-OpenMPI-4.1.6"
UPH_MODULE_PYTHON="lang/Python/3.11.5"
UPH_MODULE_JULIA="lang/JuliaHPC"
UPH_MODULE_CONTAINER="system/Apptainer"
```

For a clean reproducible build environment:

```bash
modpurge
modload cpp mpi hdf5 cmake
modlist
which gcc g++ gfortran mpicc mpicxx h5cc h5pcc cmake
```

`modpurge` removes all currently loaded modules, so use it only when replacing the current environment. `modload` itself does not purge automatically and can extend an existing module stack.

#### PC2 Software and Runtime Directories

PC2 distinguishes storage by purpose:

- `$HOME`: small permanent configuration only; backed up and quota-limited.
- `$PC2DATA/<project>`: permanent project data. PC2 recommends this for Python environments and packages.
- `$PC2PFS/<project>`: parallel temporary computation data. Use this for active jobs, Julia depots, and large container images/caches.

Avoid package depots and large caches in `$HOME`. Configure paths in `~/.config/hpc/local.sh`, replacing the project acronym:

```sh
UPH_PC2_PROJECT="hpc-prf-<project>"
UPH_SCRATCH_DIR="$PC2PFS/$UPH_PC2_PROJECT"

# Python: persistent project storage is preferred.
export PYTHONUSERBASE="$PC2DATA/$UPH_PC2_PROJECT/python-user"
export PIP_CACHE_DIR="$PC2DATA/$UPH_PC2_PROJECT/pip-cache"

# Julia: keep a cluster-specific depot on the parallel filesystem.
export JULIA_DEPOT_PATH="$PC2PFS/$UPH_PC2_PROJECT/.julia"

# Apptainer/Singularity: keep large image caches outside HOME.
export APPTAINER_CACHEDIR="$PC2PFS/$UPH_PC2_PROJECT/apptainer-cache"
export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
export APPTAINER_TMPDIR="/dev/shm/$USER"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"
```

Create the configured directories once:

```bash
mkdir -p "$PYTHONUSERBASE" "$PIP_CACHE_DIR" "$JULIA_DEPOT_PATH"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
```

For Conda, move both environments and package caches away from `$HOME`:

```bash
conda config --add envs_dirs "$PC2DATA/$UPH_PC2_PROJECT/conda/envs"
conda config --add pkgs_dirs "$PC2DATA/$UPH_PC2_PROJECT/conda/pkgs"
```

Use separate Python/Conda and Julia environments for clusters with different CPU architectures. Binary packages compiled for one cluster may not be compatible with another.

If software is unavailable through modules:

1. Search with `software_find <name>`.
2. Ask `pc2-support@uni-paderborn.de` whether it can be installed centrally.
3. Use Python, Julia, or Conda package environments in project storage.
4. Use `modload_container` and Apptainer/Singularity for a containerized environment.
5. As a last resort, build with a project-local prefix such as `./configure --prefix="$PC2PFS/$UPH_PC2_PROJECT/prefix"`.

PC2 references used for this integration:

- [Finding Software](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1900614/Finding+Software)
- [Loading Software Environments Using Modules](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1900596)
- [File Systems](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1901764/File+Systems)
- [Python](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1903900)
- [Julia](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1902093)
- [Singularity Introduction](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1900673)

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
inter -c 8 -t 01:00:00 -m 16G
# Include cluster-specific scheduling fields when required:
inter -c 8 -t 01:00:00 -m 16G -p normal -A my-project
```

This expands to the PC2-supported form:

```bash
srun --nodes=1 --ntasks=1 --cpus-per-task=8 \
    --time=01:00:00 --mem=16G \
    --partition=normal --account=my-project \
    --pty "$SHELL" -l
```

Important details:

- `inter` lazily loads the `slurm` module when `srun` is not already in `PATH`. Override its name with `UPH_MODULE_SLURM` if required.
- A numeric time such as `-t 30` is passed to Slurm unchanged and means **30 minutes**. Use `-t 02:00:00` for two hours.
- If you belong to several compute-time projects, specify `-A <project>` or set `UPH_SLURM_ACCOUNT`, `SLURM_ACCOUNT`, or `SBATCH_ACCOUNT`.
- A partition selects hardware; QoS controls priority and policy.
- Interactive jobs may remain pending and are not recommended for unattended production work.

For a generic GPU request:

```bash
inter -c 16 -t 01:00:00 -p dgx -q devel -g a100:1
```

The `-g` option produces PC2's documented GRES syntax:

```text
-g 1       -> --gres=gpu:1
-g a100:2  -> --gres=gpu:a100:2
```

For Noctua 2 development/testing, use:

```bash
inter_gpu 1
inter_gpu 4
```

`inter_gpu` follows PC2's published policy:

| GPUs | CPU cores | Maximum time |
| ---: | ---: | ---: |
| 1 | 16 | 04:00:00 |
| 2 | 32 | 03:30:00 |
| 3 | 48 | 03:00:00 |
| 4 | 64 | 02:30:00 |
| 5 | 80 | 02:00:00 |
| 6 | 96 | 01:30:00 |
| 7 | 112 | 01:00:00 |
| 8 | 128 | 00:30:00 |

It is intended for GPU development and testing, not production workloads.

If `inter` reports that `srun` is unavailable, inspect and restore the PC2 module environment:

```bash
module list
module load slurm
command -v srun
inter -c 8 -t 01:00:00 -m 16G
```

If `module load slurm` fails:

```bash
software_find slurm
modspider slurm
```

Then place the exact module name in `~/.config/hpc/local.sh`:

```sh
UPH_MODULE_SLURM="slurm/<version>"
```

PC2 references:

- [Interactive Jobs](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1903234/Interactive+Jobs)
- [Running Compute Jobs](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1902952/Running+Compute+Jobs)
- [Node Types and Partitions](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1902981/Node+Types+and+Partitions)
- [Quality-of-Service and Job Priorities](https://upb-pc2.atlassian.net/wiki/spaces/PC2DOK/pages/1902070/Quality-of-Service+QoS+and+Job+Priorities)

### 5. High-Speed Parallel Disk Workflows

HPC nodes have high-speed parallel file systems (like Lustre) mounted on `/scratch` or `/work`. Use the `mkscratch` command on the cluster to navigate directly to high-speed scratch space, which auto-creates a symbolic link (`~/scratch`) in the home folder:

```bash
lustreinfo
hpc_find_scratch
mkscratch
```

If Lustre is detected but no user directory is found, configure the cluster-assigned path in `~/.config/hpc/local.sh` as described in [Lustre and Scratch Configuration](#lustre-and-scratch-configuration).

### 6. Resource Audits

After a job completes, review its CPU/Memory usage efficiency so you can tune future Slurm submission headers (this reduces queue waiting times!):

```bash
jobeff <job_id>
```

## License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Inspired by the need for a streamlined scientific computing environment that integrates local development, note-taking, and HPC workflows.
- Built using Oh My Zsh and various open-source CLI tools.
- Special thanks to the open-source community for providing the tools and libraries that make this configuration possible.
- Created by Maks Kliczkowski (2024-2026). Feel free to fork, customize, and contribute back!

---
