# Generic run-directory helpers for portable scientific batch scripts.
# Source from Bash or Zsh. Slurm is optional.
# shellcheck shell=bash

_uph_run_warn() {
    printf '%s\n' "$*" >&2
}

_uph_json_escape() {
    awk 'BEGIN { ORS = "" }
        {
            gsub(/\\/, "\\\\\\\\")
            gsub(/"/, "\\\"")
            if (NR > 1) {
                printf "\\n"
            }
            printf "%s", $0
        }'
}

_uph_json_value() {
    printf '%s' "${1:-}" | _uph_json_escape
}

_uph_host() {
    hostname 2>/dev/null || uname -n 2>/dev/null || printf '%s\n' unknown
}

_uph_cpus() {
    if [ -n "${SLURM_CPUS_PER_TASK:-}" ]; then
        printf '%s\n' "$SLURM_CPUS_PER_TASK"
    elif command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || printf '%s\n' unknown
    else
        printf '%s\n' unknown
    fi
}

# Initialize the generic run root and create it when needed.
uph_init_run_roots() {
    if [ -z "${HPC_RUN_ROOT:-}" ]; then
        if [ -n "${HPC_SCRATCH_DIR:-}" ]; then
            HPC_RUN_ROOT="$HPC_SCRATCH_DIR/runs"
        elif command -v hpc_find_scratch >/dev/null 2>&1; then
            HPC_RUN_ROOT=$(hpc_find_scratch 2>/dev/null || printf '%s' "$HOME/scratch")/runs
        else
            HPC_RUN_ROOT="$HOME/scratch/runs"
        fi
    fi
    export HPC_RUN_ROOT
    mkdir -p "$HPC_RUN_ROOT" || return 1
}

uph_run_id() {
    if [ -n "${SLURM_JOB_ID:-}" ]; then
        printf '%s\n' "$SLURM_JOB_ID"
    else
        date '+%Y%m%d_%H%M%S'
    fi
}

# Create a per-run directory layout and export standard run path variables.
uph_make_run_dir() {
    if [ -z "${1:-}" ]; then
        _uph_run_warn "Usage: uph_make_run_dir <name>"
        return 1
    fi

    uph_init_run_roots || return 1

    RUN_DIR="$HPC_RUN_ROOT/$1_$(uph_run_id)"
    LOG_DIR="$RUN_DIR/logs"
    OUTPUT_DIR="$RUN_DIR/output"
    TMP_DIR="$RUN_DIR/tmp"
    STATUS_JSON="$RUN_DIR/status.json"
    RESULT_JSON="$RUN_DIR/result.json"
    MANIFEST_TXT="$RUN_DIR/manifest.txt"

    export RUN_DIR
    export LOG_DIR
    export OUTPUT_DIR
    export TMP_DIR
    export STATUS_JSON
    export RESULT_JSON
    export MANIFEST_TXT

    mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$TMP_DIR" || return 1
}

# Write a small shell-generated JSON status file for the current run.
uph_json_status() {
    if [ -z "${1:-}" ]; then
        _uph_run_warn "Usage: uph_json_status <status> [message]"
        return 1
    fi
    if [ -z "${STATUS_JSON:-}" ]; then
        _uph_run_warn "STATUS_JSON is not set; run uph_make_run_dir first."
        return 1
    fi

    mkdir -p "${STATUS_JSON%/*}" || return 1
    cat > "$STATUS_JSON" <<EOF
{
  "status": "$(_uph_json_value "$1")",
  "message": "$(_uph_json_value "${2:-}")",
  "time": "$(_uph_json_value "$(date -u '+%Y-%m-%dT%H:%M:%SZ')")",
  "host": "$(_uph_json_value "$(_uph_host)")",
  "slurm_job": "$(_uph_json_value "${SLURM_JOB_ID:-}")",
  "run_dir": "$(_uph_json_value "${RUN_DIR:-}")"
}
EOF
}

# Write a plain-text run manifest with environment, path, and command details.
uph_write_manifest() {
    if [ -z "${MANIFEST_TXT:-}" ]; then
        _uph_run_warn "MANIFEST_TXT is not set; run uph_make_run_dir first."
        return 1
    fi

    mkdir -p "${MANIFEST_TXT%/*}" || return 1
    {
        printf 'date=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'host=%s\n' "$(_uph_host)"
        printf 'user=%s\n' "${USER:-$(id -un 2>/dev/null || printf '%s' unknown)}"
        printf 'shell=%s\n' "${SHELL:-}"
        printf 'pwd=%s\n' "$PWD"
        printf 'run_dir=%s\n' "${RUN_DIR:-}"
        printf 'output_dir=%s\n' "${OUTPUT_DIR:-}"
        printf 'log_dir=%s\n' "${LOG_DIR:-}"
        printf 'tmp_dir=%s\n' "${TMP_DIR:-}"
        printf 'slurm_job=%s\n' "${SLURM_JOB_ID:-}"
        printf 'slurm_name=%s\n' "${SLURM_JOB_NAME:-}"
        printf 'slurm_node=%s\n' "${SLURM_NODELIST:-${SLURMD_NODENAME:-}}"
        printf 'cpus=%s\n' "$(_uph_cpus)"
        printf 'command=%s\n' "$*"
    } > "$MANIFEST_TXT"
}

# Write Git commit, branch, dirty count, and short status when repo is Git-backed.
uph_write_git_manifest() {
    local repo
    local out

    repo="${1:-$PWD}"
    out="${2:-${RUN_DIR:-$PWD}/git.txt}"

    mkdir -p "${out%/*}" || return 1
    if command -v git >/dev/null 2>&1 &&
        git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        {
            printf 'repo=%s\n' "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
            printf 'commit=%s\n' "$(git -C "$repo" rev-parse HEAD 2>/dev/null)"
            printf 'branch=%s\n' "$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
            printf 'dirty_files=%s\n' "$(git -C "$repo" status --short 2>/dev/null | wc -l | awk '{ print $1 }')"
            printf '\n[git status --short]\n'
            git -C "$repo" status --short 2>/dev/null
        } > "$out"
    else
        {
            printf 'repo=%s\n' "$repo"
            printf 'commit=none\n'
            printf 'branch=none\n'
            printf 'dirty_files=0\n'
        } > "$out"
    fi
}

# Run a command inside a new run directory with stdout/stderr logs and status JSON.
uph_run() {
    local run_name
    local start_dir
    local exit_code

    if [ "$#" -lt 2 ]; then
        _uph_run_warn "Usage: uph_run <name> <command> [args...]"
        return 1
    fi

    run_name="$1"
    shift
    start_dir="$PWD"

    uph_make_run_dir "$run_name" || return 1
    uph_write_manifest "$@"
    uph_write_git_manifest "$start_dir" "$RUN_DIR/git.txt"
    uph_json_status running

    cd "$RUN_DIR" || {
        uph_json_status failed "Could not enter run directory"
        return 1
    }

    "$@" > "$LOG_DIR/stdout.log" 2> "$LOG_DIR/stderr.log"
    exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
        uph_json_status completed
    else
        uph_json_status failed "Command exited with status $exit_code"
    fi

    cd "$start_dir" >/dev/null 2>&1 || true
    return "$exit_code"
}
