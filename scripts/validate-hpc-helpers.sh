#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$ROOT_DIR"

bash -n common-run.sh
bash -n common-slurm.zsh

if command -v zsh >/dev/null 2>&1; then
    zsh -n common-slurm.zsh
fi

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck common-run.sh common-slurm.zsh
fi

tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT HUP INT TERM

UPH_PROJECT_NAME=test-project UPH_SCRATCH_ROOT="$tmp_root" bash -c '
    set -eu
    . ./common-run.sh
    uph_make_run_dir test
    uph_write_manifest echo hello
    uph_json_status running
    test -d "$RUN_DIR/logs"
    test -d "$RUN_DIR/output"
    test -d "$RUN_DIR/tmp"
    test -f "$STATUS_JSON"
    test -f "$MANIFEST_TXT"
'

bash -c '
    . ./common-slurm.zsh
    . ./common-run.sh
    type hpchelp >/dev/null 2>&1
    type uph_make_run_dir >/dev/null 2>&1
'

printf '%s\n' "HPC helper validation passed."
