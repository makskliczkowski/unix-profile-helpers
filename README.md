# Unix Profile Helpers

Portable shell helpers for local Unix profiles and remote HPC/Slurm sessions.

The remote HPC layer is intentionally generic. Shared files should not contain
private project paths, account names, cluster-specific module versions, or
project environments.

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

## Install Locally

Run the deployer from this directory:

```bash
chmod +x deploy.sh
./deploy.sh
```

The deployer creates local profile files and preserves existing local override
files. To update only a remote cluster:

```bash
./deploy.sh --remote-only
```

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
export UPH_MODULE_CMAKE="cmake-module"
export UPH_MODULE_CONTAINER="container-module"
```

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

`mkslurm` creates a minimal Slurm script. It does not purge or load modules.
It includes only commented examples such as:

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

Scratch detection uses `UPH_SCRATCH_DIR`, common environment variables such as
`SCRATCH` and `WORK`, common user scratch paths, and detected Lustre mounts.
Set `UPH_SCRATCH_DIR` in `local.sh` when the cluster uses a project-specific
layout.

Set `UPH_QUOTA_GROUP` when the filesystem reports group quotas rather than user
quotas.

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

Do not commit private project paths, account names, project environments, or
cluster-specific module versions. Put them in `~/.config/hpc/local.sh` or
`~/.config/hpc/envs/*.sh` on the cluster.
