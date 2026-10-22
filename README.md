# Unix Profile Helpers

Portable shell helpers for Linux and macOS workstations and for Slurm login nodes. Cluster choices live in declarative `HPC_*` profile files, which the shell helpers and external tools read through the same loader. The shared files contain no site-specific values.

## Files

- `common-profile.sh`: profile loader, defaults, `hpc_env_apply`. Bash and Zsh.
- `profiles/example.sh`: documented example profile; copy it to `<cluster>.sh`.
- `common-slurm.sh`: `hpcprofile`, queue and job helpers, interactive allocations, sbatch template, module and scratch helpers. Bash and Zsh.
- `common-run.sh`: run directories with logs, manifest, Git metadata and `status.json`. Bash and Zsh.
- `common-safety.sh`: safe interactive defaults. Bash and Zsh; sourceable on its own.
- `zshrc`, `common-aliases.zsh`, `local.zsh.example`: local Zsh setup.
- `deploy.sh`: local install and, optionally, remote install.
- `scripts/remote-setup.sh`: install, remove or inspect the helpers on a login node.
- `scripts/install-font.sh`: install a monospace terminal font for the current user.
- `scripts/profile-dump.sh`: serializer for external tools; emits `KEY<TAB>base64(value)`, array keys repeated.
- `scripts/validate-hpc-helpers.sh`: syntax checks and smoke tests.

## Quick start

```bash
git clone https://github.com/makskliczkowski/unix-profile-helpers.git
cd unix-profile-helpers
./deploy.sh
```

`deploy.sh` backs up and replaces `~/.zshrc` and the files under `~/.config/zsh/`, creates `~/.config/zsh/local.zsh` and an example profile once, and installs `common-profile.sh` under `~/.config/hpc/`. Machine-specific choices go in `local.zsh`, cluster choices in a profile. Oh My Zsh is optional; install it before running the deployer, because its installer may replace `~/.zshrc`.

## Profiles

A profile is a trusted local shell fragment containing assignments only. It is looked up as `$HPC_PROFILE_DIR/<name>.sh` (default `~/.config/hpc/profiles`) or given as an explicit `.sh` path. A profile describes the account on a cluster. Optional run presets live beside it as `<name>.d/<run>.sh`, hold only the keys they override, and are selected with `<name>:<run>`.

```bash
. ~/.config/hpc/common-profile.sh
hpc_profile_load mycluster:gpu
hpc_profile_show
```

`common-slurm.sh` adds the `hpcprofile list|use NAME|show|path|dir` command. `HPC_PROFILE` selects a profile when the helpers are sourced, otherwise `default.sh` is loaded if present. `HPC_PROFILE_AUTOLOAD=0` disables this. Use `~` instead of `$HOME` in path values: the profile is sourced locally, so `$HOME` would expand to the local home.

### Schema

Scalars:

| Key | Meaning |
| --- | --- |
| `HPC_NAME`, `HPC_DESCRIPTION`, `HPC_NOTES` | Identifier (usually the file stem), summary, free-form notes. |
| `HPC_SSH_HOST` | `~/.ssh/config` alias or hostname. |
| `HPC_SSH_USER`, `HPC_SSH_PORT`, `HPC_SSH_PROXYJUMP`, `HPC_SSH_IDENTITY` | Optional connection details added to the alias. |
| `HPC_SLURM_ACCOUNT` | Project (billing) account; distinct from the login user. |
| `HPC_SLURM_PARTITION`, `HPC_SLURM_QOS`, `HPC_SLURM_TIME`, `HPC_SLURM_MEM`, `HPC_SLURM_CPUS`, `HPC_SLURM_NODES` | Scheduler defaults. |
| `HPC_SLURM_GPUS` | GPU count or GRES, for example `1` or `a100:2`. |
| `HPC_SLURM_GPU_STYLE` | `gres` (default), `gpus` or `gpus-per-node`. |
| `HPC_SLURM_MAIL` | Address for `--mail-user`; adds `--mail-type=END,FAIL`. |
| `HPC_ENV_INIT` | Snippet that makes `module` available when it is a shell function. |
| `HPC_ENV_PURGE` | `true` (default) runs `module purge` before loading modules. |
| `HPC_ENV_CONDA` | Conda environment name or prefix, activated after the modules. |
| `HPC_SCRATCH_DIR`, `HPC_QUOTA_GROUP` | Scratch location and quota group for the storage helpers. |
| `HPC_SHELL`, `HPC_WORKDIR`, `HPC_PYTHON` | Interactive shell, remote working directory, Python executable. |
| `HPC_JUPYTER_CMD`, `HPC_JUPYTER_IP`, `HPC_JUPYTER_PORT` | Jupyter command (`jupyter lab`), bind address (`0.0.0.0`), preferred port (`0` picks a free one). |
| `HPC_TERM_BASHRC` | `true` (default) or `false`: whether a terminal started by an external tool sources `~/.bashrc`. |

Arrays: `HPC_SSH_OPTIONS`, `HPC_SLURM_EXTRA` (raw `sbatch` options), `HPC_ENV_MODULES`, `HPC_ENV_SOURCE` (files sourced after modules and conda), `HPC_ENV_VARS` (`KEY=VALUE`), `HPC_ENV_PRE` (commands), `HPC_JUPYTER_EXTRA`, `HPC_TERM_SOURCE` (extra files sourced at terminal start).

### What is exported

Loading a profile sets the `HPC_*` values as plain shell variables, which are enough for the functions in the same shell and are not visible to child processes. Only `HPC_PROFILE` and `HPC_PROFILE_RUN` are exported, so that a child shell selects the same profile and run preset. Account names, paths and other values therefore never leak into unrelated programs.

Entries of `HPC_ENV_VARS` are exported only by `hpc_env_apply`, which an external terminal launcher, a job script or the user calls explicitly. Sourcing a helper file never does it. The function runs in the current shell in this order: `HPC_ENV_INIT`, `module purge`, modules, conda, `HPC_ENV_SOURCE` files, `HPC_ENV_VARS`, `HPC_ENV_PRE`. It stops at the first failing step. Each `HPC_ENV_VARS` entry is `KEY=VALUE` and is exported with its value quoted, so values with spaces work. A leading `~`, `$VAR` and `${VAR}` expand; command substitution and arithmetic do not, so a profile value cannot run code through this path. `HPC_ENV_SOURCE` paths get the same expansion. `HPC_ENV_INIT` and `HPC_ENV_PRE` are shell code by design.

## Remote helpers

`scripts/remote-setup.sh` installs the Bash-compatible subset (`common-profile.sh`, `common-slurm.sh`, `common-run.sh`, `common-safety.sh`) into `~/.config/hpc/` and keeps one marked block in `~/.bashrc`:

```text
# >>> unix-profile-helpers >>>
...
# <<< unix-profile-helpers <<<
```

```bash
scripts/remote-setup.sh install   [--dry-run] [--from DIR]
scripts/remote-setup.sh uninstall [--dry-run]
scripts/remote-setup.sh status    [--from DIR]
```

`install` is idempotent; a re-run replaces the block in place. Before the first change `~/.bashrc` is copied once to `~/.bashrc.uph-backup`. `uninstall` removes exactly that block and the four files, and leaves profiles, the backup and the rest of `~/.bashrc` alone. It refuses to edit a `~/.bashrc` whose block markers are unbalanced. `--dry-run` writes nothing. `--from DIR` names the directory holding the source files (default: the repository), which allows streaming to a temporary directory on the login node, as `deploy.sh` does:

```bash
tar -C unix-profile-helpers -cf - common-*.sh scripts/remote-setup.sh |
    ssh cluster 'd=$(mktemp -d) && tar -xf - -C "$d" && sh "$d/scripts/remote-setup.sh" install --from "$d"; rm -rf "$d"'
```

Every command prints one `key=value` per line. `status` reports `dir`, `bashrc`, `block` (`present`/`absent`), `backup`, `file.<name>` (`present`/`missing`), `installed` (`yes`/`partial`/`no`) and `up_to_date` (`yes`/`no`/`unknown`, comparing against `--from`). `install` and `uninstall` report `block`, `backup` and `file.<name>` outcomes, preceded by `dry_run=1` in a dry run.

`./deploy.sh --remote-only` asks for an SSH address, optionally authorizes your public key, and runs the installer this way. Cluster profiles are not copied; create them in `~/.config/hpc/profiles/` on the remote account or with an external tool.

## Safety defaults

`common-safety.sh` applies to interactive shells only and is loaded by `zshrc` and by the remote block. `UPH_SAFE=0` disables it.

- `umask 077`, so new files are private. Set `UPH_UMASK=027` to share with a group.
- Commands typed with a leading space stay out of the history. Type secrets that way, or read them with `read -rs VAR`; never put tokens on a command line or in a profile.
- `set -o noclobber`: `>` refuses to overwrite an existing file; use `>|` to force.
- `cp -i`, `mv -i`, and `rm -I` (`rm -i` where unsupported) ask before destroying data.

## Terminal font

```bash
scripts/install-font.sh             # JetBrains Mono, current user, no sudo
scripts/install-font.sh --dry-run
scripts/install-font.sh --uninstall
```

The font (SIL OFL 1.1) comes from the official GitHub release over https into `~/.local/share/fonts` (then `fc-cache`) or `~/Library/Fonts`. The project publishes no checksum, so the download's SHA-256 is printed; pass `--sha256 HASH` to require a match. Re-running with the same `--version` does nothing. Select "JetBrains Mono" in the terminal's preferences afterwards.

## Slurm, modules and runs

`hpchelp` lists the commands. In short: `sq`, `sqr`, `sqc`, `sqn`, `sac`, `jobeff`, `jobtop`, `slog`; `inter` and `salloc_quick` allocate with the profile's defaults, options override them; `mkslurm FILE` writes an sbatch template from the profile; `modload` loads the profile's modules or the ones given, `mod ARGS` runs `module ARGS` after initializing it; `hpc_find_scratch`, `mkscratch`, `myquota`, `hpcdoctor`. Put real module names in `HPC_ENV_MODULES`; there is no generic-to-site mapping.

`common-run.sh` does not need Slurm. `uph_run NAME CMD...` creates `$HPC_RUN_ROOT/<name>_<id>/{logs,output,tmp}` with `manifest.txt`, `git.txt` and `status.json`, runs the command with stdout and stderr logged, and keeps its exit status. The run root is `HPC_RUN_ROOT`, else `HPC_SCRATCH_DIR/runs`, else a detected scratch directory, else `~/scratch/runs`.

## Local Zsh

`zshrc` sets history, completion, `PATH` and `EDITOR`, and enables Oh My Zsh plugins only when they are installed. `common-aliases.zsh` holds small utilities: `ll`/`la` (via `eza` when present), `mkcd`, `extract`, `open_file`, and `rscp`, an rsync wrapper that never overwrites existing files (`--rm` moves instead of copying). Extra plugins: `typeset -ga UPH_EXTRA_PLUGINS=(kubectl)` in `local.zsh`.

## Validation

```bash
scripts/validate-hpc-helpers.sh
```

It checks Bash syntax of every shell file, Zsh syntax and the Zsh code paths when `zsh` is installed, `shellcheck` when available, profile loading, run presets, the export policy, `hpc_env_apply` ordering and expansion, the `profile-dump.sh` round trip including the terminal, mail and Jupyter keys, the safety file in a clean `bash -i`, `remote-setup.sh` install/uninstall/status in a temporary `HOME`, and `install-font.sh --dry-run`. Nothing touches the real home directory or the network.

## Policy

Do not commit private paths, account names, project environments or cluster-specific module versions. They belong in `~/.config/hpc/profiles/<cluster>.sh` or `~/.config/zsh/local.zsh`.
