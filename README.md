# Unix Profile Helpers

Portable shell helpers for local Unix profiles and remote HPC/Slurm sessions.

The remote HPC layer is intentionally generic. Shared files should not contain private project paths, account names, cluster-specific module versions, or project environments.

## Files

- `zshrc`: local workstation Zsh profile.
- `common-aliases.zsh`: local shell aliases and small utilities.
- `common-hpc.zsh`: local helpers for remote HPC access and syncing.
- `common-slurm.zsh`: remote Slurm, module, scratch/quota, and diagnostic helpers. Deploy it as `~/.config/hpc/common-slurm.sh`.
- `common-run.sh`: generic run-directory, logging, manifest, Git metadata, and status JSON helpers.
- `deploy.sh`: local and remote deployment helper.
- `scripts/validate-hpc-helpers.sh`: syntax and smoke-test validation for the remote helper layer.

Local-only files on each cluster:

- `~/.config/hpc/local.sh`: cluster/account/module/scratch defaults. Deployments preserve this file.
- `~/.config/hpc/envs/*.sh`: project-specific environments, repositories, virtual environments, and caches.

## What To Do First

The base profile requires Zsh. Everything else—including Oh My Zsh, Obsidian,
scientific-project paths, and HPC shortcuts—is optional.

1. Check that Zsh is available:

   ```bash
   zsh --version
   ```

   On Ubuntu, install it when necessary:

   ```bash
   sudo apt update
   sudo apt install zsh
   ```

   Current macOS releases include Zsh. To make it your login shell on either
   platform, run `chsh -s "$(command -v zsh)"`, then log out and back in.

2. Decide whether to use Oh My Zsh. It is not required. If you want it, install
   it **before** running this repository's deployer because its installer may
   replace an existing `~/.zshrc`:

   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

3. Clone this repository and deploy:

   ```bash
   git clone https://github.com/makskliczkowski/unix-profile-helpers.git
   cd unix-profile-helpers
   ./deploy.sh
   ```

   The deployer backs up and replaces `~/.zshrc`,
   `~/.config/zsh/common-aliases.zsh`, and
   `~/.config/zsh/common-hpc.zsh`. It creates
   `~/.config/zsh/local.zsh` once and preserves that file on later deployments.
   When `XDG_CONFIG_HOME` is set, its `zsh` directory is used instead of
   `~/.config/zsh` everywhere.

4. Validate and start the profile:

   ```bash
   zsh -n ~/.zshrc
   exec zsh
   ```

5. Put machine-specific choices in `~/.config/zsh/local.zsh`, never in the
   shared files. Start with no overrides; add only the integrations you use.

## Optional Local Features

### Editor

The profile respects an existing `EDITOR`. Otherwise it selects `nano` or `vi`
over SSH and prefers VS Code, Neovim, `nano`, then `vi` locally. Override it in
`~/.config/zsh/local.zsh` when desired:

```zsh
export EDITOR='code --wait'
export VISUAL="$EDITOR"
```

### Oh My Zsh Plugins

The profile automatically enables the bundled `docker`, `asdf`, and `zoxide`
plugins when their commands exist. It also detects these third-party plugin
directories without failing when they are absent:

- `zsh-autosuggestions`
- `zsh-history-substring-search`
- `fast-syntax-highlighting`
- `zsh-completions`

To install all four after installing Oh My Zsh:

```zsh
plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
mkdir -p "$plugin_dir"
git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-history-substring-search "$plugin_dir/zsh-history-substring-search"
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$plugin_dir/fast-syntax-highlighting"
git clone https://github.com/zsh-users/zsh-completions "$plugin_dir/zsh-completions"
```

Add other installed Oh My Zsh plugins in `local.zsh`:

```zsh
typeset -ga UPH_EXTRA_PLUGINS=(kubectl)
```

Missing extra plugins are skipped with a startup message. Set `ZSH` in
`local.zsh` if Oh My Zsh is installed outside `~/.oh-my-zsh`, and set
`ZSH_THEME` there to change the default `agnoster` theme.

### Optional Command-Line Tools

No tool in this list is required for shell startup:

- `eza` enhances `l`, `ll`, and `la`; ordinary `ls` is the fallback.
- `bat` enhances interactive `cat`; ordinary `cat` remains unchanged otherwise.
- `rg` enables `rgrep` and is required by `obsearch`. It never replaces `grep`.
- `zoxide`, `asdf`, and `docker` enable their Oh My Zsh plugins when both Oh My
  Zsh and the corresponding command are installed.
- `$HOME/.local/bin`, `$HOME/.juliaup/bin`, and existing Homebrew directories
  are added to `PATH` only when present.
- Conda is initialized lazily on first use from common Miniforge, Miniconda,
  Anaconda, or Homebrew locations.

### Obsidian

Choose Obsidian setup in `./deploy.sh`, or enable it later in `local.zsh`:

```zsh
export OBSIDIAN_VAULT="$HOME/Documents/PhysicsNotes"
```

Leave the variable unset to disable the integration. `mkobsidian`, `obsearch`,
and `obnew` remain harmless and explain how to enable it when called.

### Code and QuantumEigenSolver Paths

The `codes` helper defaults to `$HOME/Codes`. Override it when needed:

```zsh
export UPH_CODES_DIR="$HOME/src"
```

QuantumEigenSolver integration is disabled by default. Enable and configure it
only on machines containing that project:

```zsh
UPH_ENABLE_SOLVER_PATHS=true
export QES_ROOT="$HOME/Codes/QuantumEigenSolver"
```

This derives `QES_PYQUSOLVER_DIR`, `QES_PYPATH`,
`QES_PYPATH_GEN_PYTHON`, and `QES_SLURMPATH`. Override any derived value below
`QES_ROOT` in `local.zsh` when the repository layout differs.

### Local HPC Shortcuts

The generic `hpc-sync-to SOURCE USER@HOST:PATH` helper needs only `rsync` and
SSH. These convenience shortcuts are disabled until configured in `local.zsh`:

```zsh
export UPH_HPC_HOST="my-cluster"  # SSH config host or user@host
export UPH_QES_REMOTE="my-cluster:~/path/to/pyqusolver/"
```

`UPH_HPC_HOST` enables `hpclogin`. `UPH_QES_REMOTE` enables `qessync` when the
QuantumEigenSolver paths above are also enabled.

### Armadillo Compiler Helper

`armacmp FILE.cpp` requires `g++` and the Armadillo library. Normally its
system include path needs no configuration. For a custom installation, set:

```zsh
export ARMADILLO_INCL_DIR="$HOME/path/to/armadillo/include"
```

## Remote Deployment

Run `./deploy.sh` and opt into remote deployment at the final prompt, or update
only a remote machine later:

```bash
./deploy.sh --remote-only
```

Remote deployment requires `ssh` and `scp`. It creates and preserves the
cluster-local override file `~/.config/hpc/local.sh`.

The initial remote prompt controls copying and configuring the remote helpers.
SSH-key authorization is a separate opt-in; when accepted, it appends the
selected local public key to the remote `~/.ssh/authorized_keys`. Declining it
still allows password-based deployment. The deployer then asks which remote
profile, `.bashrc` or `.zshrc`, to update and verifies the installed helpers before
reporting success.

## Deploy Remote Helpers Manually

```bash
ssh user@cluster 'mkdir -p ~/.config/hpc'
scp common-slurm.zsh user@cluster:~/.config/hpc/common-slurm.sh
scp common-run.sh user@cluster:~/.config/hpc/common-run.sh
```

Source them from the remote shell profile:

```bash
if [ -f "$HOME/.config/hpc/common-slurm.sh" ]; then
    . "$HOME/.config/hpc/common-slurm.sh"
fi
if [ -f "$HOME/.config/hpc/common-run.sh" ]; then
    . "$HOME/.config/hpc/common-run.sh"
fi
```

## Local Cluster Configuration

Put cluster-specific values in `~/.config/hpc/local.sh`:

```sh
export UPH_SLURM_ACCOUNT="my-account"
export UPH_SLURM_PARTITION="normal"
export UPH_SLURM_QOS=""
export UPH_SLURM_CPUS="4"
export UPH_SLURM_TIME="01:00:00"
export UPH_SLURM_MEMORY="4G"
export UPH_SLURM_GRES="gpu:1"
export UPH_INTERACTIVE_SHELL="/bin/bash"

export UPH_SCRATCH_DIR="/path/to/scratch"
export UPH_QUOTA_GROUP="my-account"

export UPH_MODULE_SLURM="slurm"
export UPH_MODULE_COMPILER="compiler-module"
export UPH_MODULE_MPI="mpi-module"
export UPH_MODULE_HDF5="hdf5-module"
export UPH_MODULE_PYTHON="python-module"
export UPH_MODULE_JULIA="julia-module"
export UPH_MODULE_CMAKE="cmake-module"
export UPH_MODULE_CONTAINER="container-module"
export UPH_MODULE_BLAS="blas-module"
export UPH_MODULE_BOOST="boost-module"
export UPH_MODULE_NETCDF="netcdf-module"
```

All cluster values are optional. Unset scheduler options are omitted from
generated commands; unset module mappings are skipped. Begin with the account,
partition, scratch directory, and only the module names your cluster actually
provides. `modset --persist PROFILE MODULE` can add mappings later without
manually editing the file.

Use `~/.config/hpc/envs/myproject.sh` for project-specific setup:

```sh
export UPH_PROJECT_NAME="myproject"
export MYPROJECT_REPO="$HOME/path/to/myproject"
export MYPROJECT_VENV="$MYPROJECT_REPO/.venv"

export UPH_PROJECT_ROOT="${UPH_SCRATCH_ROOT:-$HOME/scratch}/Projects/$UPH_PROJECT_NAME"
export UPH_RUN_ROOT="$UPH_PROJECT_ROOT/runs"
export UPH_LOG_ROOT="$UPH_PROJECT_ROOT/logs"
export UPH_TMP_ROOT="$UPH_PROJECT_ROOT/tmp"
export UPH_CACHE_ROOT="$UPH_PROJECT_ROOT/cache"
export UPH_CHECKPOINT_ROOT="$UPH_PROJECT_ROOT/checkpoints"

mkdir -p "$UPH_RUN_ROOT" "$UPH_LOG_ROOT" "$UPH_TMP_ROOT" \
    "$UPH_CACHE_ROOT" "$UPH_CHECKPOINT_ROOT"

if [ -d "$MYPROJECT_VENV" ]; then
    . "$MYPROJECT_VENV/bin/activate"
fi
```

## Slurm Helpers

Queue and accounting:

```bash
sq
sqr
sqn
sac
jobeff <job_id>
jobtop <job_id>
```

Interactive allocations:

```bash
inter -c 8 -t 01:00:00 -m 16G
inter -c 16 -t 01:00:00 -g gpu:1
salloc_quick 4 02:00:00 normal
```

Templates:

```bash
mkslurm job.sh
mkslurm_cockpit cockpit-job.sh
```

`mkslurm` creates a minimal Slurm script. It does not purge or load modules. It includes only commented examples such as:

```bash
# Optional modules:
# modload cpp mpi hdf5 python
```

## Module Helpers

Map generic profiles to local module names:

```bash
modset --persist cpp compiler-module
modset --persist mpi mpi-module
modset --persist hdf5 hdf5-module
modset --persist python python-module
```

Load profiles:

```bash
modload cpp mpi hdf5 python
modload science
```

Inspect mappings:

```bash
modget
modget hdf5
modunset --persist hdf5
```

## Scratch and Quota Helpers

```bash
lustreinfo
hpc_find_scratch
mkscratch
myquota
hpcdoctor
```

Scratch detection uses `UPH_SCRATCH_DIR`, common environment variables such as `SCRATCH` and `WORK`, common user scratch paths, and detected Lustre mounts. Set `UPH_SCRATCH_DIR` in `local.sh` when the cluster uses a project-specific layout.

Set `UPH_QUOTA_GROUP` when the filesystem reports group quotas rather than user quotas.

## Run Helpers

`common-run.sh` does not require Slurm.

```bash
uph_make_run_dir test
uph_write_manifest echo hello
uph_json_status running
uph_write_git_manifest
```

Run a command with standard logs and status files:

```bash
uph_run example ./solver --input input.dat
```

Default layout:

```text
$UPH_RUN_ROOT/<name>_<run_id>/
  logs/stdout.log
  logs/stderr.log
  output/
  tmp/
  status.json
  result.json
  manifest.txt
  git.txt
```

Run-root defaults:

1. `UPH_SCRATCH_ROOT`
2. `UPH_SCRATCH_DIR`
3. `hpc_find_scratch`
4. `$HOME/scratch`

## Cockpit-Compatible Template

Generate a structured Slurm script:

```bash
mkslurm_cockpit run-example.sh
```

The generated script:

- sources `common-slurm.sh` and `common-run.sh`,
- creates `RUN_DIR`, `LOG_DIR`, `OUTPUT_DIR`, and `TMP_DIR`,
- writes `manifest.txt`, `git.txt`, and `status.json`,
- redirects workload stdout/stderr to `logs/stdout.log` and `logs/stderr.log`,
- writes a placeholder `result.json`,
- preserves the workload exit code.

## Validation

Run:

```bash
scripts/validate-hpc-helpers.sh
```

It checks:

- `bash -n common-run.sh`
- `bash -n common-slurm.zsh`
- `zsh -n common-slurm.zsh` when `zsh` is available
- `shellcheck common-run.sh common-slurm.zsh` when `shellcheck` is available
- sourceability and a temporary run-directory smoke test

## Policy

Do not commit private project paths, account names, project environments, or cluster-specific module versions. Put them in `~/.config/hpc/local.sh` or `~/.config/hpc/envs/*.sh` on the cluster.
