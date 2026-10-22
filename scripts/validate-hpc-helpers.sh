#!/usr/bin/env bash
# Syntax checks and smoke tests for the helpers. Uses a temporary HOME; no
# network, no writes outside it. Zsh checks run only when zsh is installed.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
# Isolate everything from the real home and configuration.
export HOME="$tmp/home"
mkdir -p "$HOME"
unset XDG_CONFIG_HOME XDG_DATA_HOME HPC_PROFILE HPC_PROFILE_RUN HPC_PROFILE_DIR UPH_SAFE UPH_UMASK

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }
have_zsh() { command -v zsh >/dev/null 2>&1; }

# ---- syntax -----------------------------------------------------------------
sh_files="common-profile.sh common-slurm.sh common-run.sh common-safety.sh deploy.sh
          profiles/example.sh scripts/profile-dump.sh scripts/remote-setup.sh
          scripts/install-font.sh scripts/validate-hpc-helpers.sh"
for f in $sh_files; do bash -n "$f" || fail "bash -n $f"; done
if have_zsh; then
    for f in common-profile.sh common-slurm.sh common-run.sh common-safety.sh \
             zshrc common-aliases.zsh local.zsh.example; do
        zsh -n "$f" || fail "zsh -n $f"
    done
fi
if command -v shellcheck >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    shellcheck -x $sh_files || fail "shellcheck"
fi

# ---- profiles ---------------------------------------------------------------
mkdir -p "$tmp/profiles/test.d"
cat > "$tmp/profiles/test.sh" <<'PROFILE'
HPC_NAME="test"
HPC_SSH_HOST="cluster.example"
HPC_SSH_USER="login-user"
HPC_SLURM_ACCOUNT="project-account"
HPC_SLURM_PARTITION="batch"
HPC_SLURM_MAIL="me@example.org"
HPC_SLURM_EXTRA=("--exclusive")
HPC_ENV_INIT="ORDER=init"
HPC_ENV_MODULES=("m1" "m2")
HPC_ENV_SOURCE=("~/src.sh")
HPC_ENV_VARS=('GREETING=hello world' 'ORDER=${ORDER},vars' 'REF=$HOME/x' 'TILDE=~/y' 'CMD=$(echo pwned)' 'DFLT=${NOPE:-$(echo pwned)}')
HPC_ENV_PRE=('ORDER=$ORDER,pre; export ORDER')
HPC_JUPYTER_IP="127.0.0.1"
HPC_TERM_BASHRC="false"
HPC_TERM_SOURCE=("~/one.sh" "two words.sh")
HPC_SCRATCH_DIR="/scratch/$USER"
PROFILE
printf 'HPC_SLURM_PARTITION="gpu"\n' > "$tmp/profiles/test.d/gpu.sh"
printf 'HPC_NAME="empty"\nHPC_SSH_HOST="other.example"\n' > "$tmp/profiles/empty.sh"
printf 'ORDER=$ORDER,src\n' > "$HOME/src.sh"

# Shared by bash and zsh: loading, clearing, defaults, run presets, export policy.
cat > "$tmp/load-test.sh" <<'BODY'
fail() { printf 'FAIL(%s): %s\n' "${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}" "$*" >&2; exit 1; }
expect() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }
. ./common-profile.sh
hpc_profile_load test || fail load
expect name "$HPC_PROFILE" test
expect user "$HPC_SSH_USER" login-user
expect time-default "$HPC_SLURM_TIME" 08:00:00
expect jupyter-ip "$HPC_JUPYTER_IP" 127.0.0.1
expect term-bashrc "$HPC_TERM_BASHRC" false
expect term-source-count "${#HPC_TERM_SOURCE[@]}" 2
expect modules "${HPC_ENV_MODULES[*]}" "m1 m2"
hpc_profile_list | grep -qx test || fail list
hpc_profile_show | grep -q "profile   test" || fail show

# Export policy: only HPC_PROFILE and HPC_PROFILE_RUN reach child processes.
expect child-profile "$(sh -c 'echo "${HPC_PROFILE-}"')" test
expect child-account "$(sh -c 'echo "${HPC_SLURM_ACCOUNT-unset}"')" unset
expect child-greeting "$(sh -c 'echo "${GREETING-unset}"')" unset

hpc_profile_load test:gpu || fail preset
expect preset "$HPC_SLURM_PARTITION" gpu
expect preset-run "$HPC_PROFILE_RUN" gpu
expect preset-keeps "$HPC_SSH_USER" login-user
hpc_profile_load nonexistent 2>/dev/null && fail "missing profile accepted"
hpc_profile_load test:../x 2>/dev/null && fail "bad run name accepted"

hpc_profile_load empty || fail load-empty
expect cleared "${HPC_SLURM_ACCOUNT:-}" ""
expect cleared-mail "${HPC_SLURM_MAIL:-}" ""
expect cleared-source "${#HPC_TERM_SOURCE[@]}" 0
expect default-bashrc "$HPC_TERM_BASHRC" true
expect default-ip "$HPC_JUPYTER_IP" 0.0.0.0
BODY
HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE_AUTOLOAD=0 bash "$tmp/load-test.sh"
have_zsh && HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE_AUTOLOAD=0 zsh "$tmp/load-test.sh"

# hpc_env_apply: order, quoting, expansion, no command substitution.
cat > "$tmp/env-test.sh" <<'BODY'
fail() { printf 'FAIL(%s): %s\n' "${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}" "$*" >&2; exit 1; }
expect() { [ "$2" = "$3" ] || fail "$1: got '$2', want '$3'"; }
module() { ORDER="$ORDER,$1${2:+:$2}"; }
. ./common-profile.sh
hpc_profile_load test || fail load
hpc_env_apply || fail apply
expect order "$ORDER" "init,purge,load:m1,load:m2,src,vars,pre"
expect spaces "$(sh -c 'echo "$GREETING"')" "hello world"
expect var "$(sh -c 'echo "$REF"')" "$HOME/x"
expect tilde "$(sh -c 'echo "$TILDE"')" "$HOME/y"
expect no-cmdsub "$(sh -c 'echo "$CMD"')" '$(echo pwned)'
expect no-cmdsub-default "$(sh -c 'echo "$DFLT"')" '$(echo pwned)'
BODY
HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE_AUTOLOAD=0 bash "$tmp/env-test.sh"
have_zsh && HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE_AUTOLOAD=0 zsh "$tmp/env-test.sh"

# Sourcing the helpers exports nothing from the profile environment.
expect autoload-no-export "$(HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE=test bash -c '. ./common-profile.sh; sh -c "echo \${GREETING-unset}"')" unset

# profile-dump keeps the KEY<TAB>base64(value) contract and round-trips new keys.
dump=$(HPC_PROFILE_DIR="$tmp/profiles" ./scripts/profile-dump.sh test)
dump_values() { printf '%s\n' "$dump" | awk -F '\t' -v k="$1" '$1 == k { print $2 }' | while IFS= read -r v; do printf '%s' "$v" | base64 -d; printf '\n'; done; }
printf '%s\n' "$dump" | awk -F '\t' 'NF != 2 { bad = 1 } END { exit bad }' || fail "dump is not KEY<TAB>base64"
expect dump-profile "$(dump_values HPC_PROFILE)" test
expect dump-mail "$(dump_values HPC_SLURM_MAIL)" me@example.org
expect dump-ip "$(dump_values HPC_JUPYTER_IP)" 127.0.0.1
expect dump-bashrc "$(dump_values HPC_TERM_BASHRC)" false
expect dump-term-source "$(dump_values HPC_TERM_SOURCE)" "$(printf '~/one.sh\ntwo words.sh')"
expect dump-vars-count "$(dump_values HPC_ENV_VARS | wc -l | tr -d ' ')" 6

# ---- slurm helpers and run directories ---------------------------------------
HPC_PROFILE_DIR="$tmp/profiles" HPC_PROFILE_AUTOLOAD=0 bash -c '
    set -eu
    . ./common-slurm.sh
    for fn in hpcprofile inter modload mod uph_make_run_dir; do type "$fn" >/dev/null 2>&1 || { echo "missing $fn"; exit 1; }; done
    hpcprofile use test >/dev/null
    opts=$(_hpc_slurm_options 1 01:00:00 "" "" "" "" "" 1)
    printf "%s\n" "$opts" | grep -qx -- "--mail-user=me@example.org"
    printf "%s\n" "$opts" | grep -qx -- "--exclusive"
' || fail "common-slurm.sh in bash"

HPC_RUN_ROOT="$tmp/runs" bash -c '
    set -eu
    . ./common-run.sh
    uph_make_run_dir test
    uph_write_manifest echo hello
    uph_json_status running
    test -d "$LOG_DIR" && test -d "$OUTPUT_DIR" && test -d "$TMP_DIR"
    test -f "$STATUS_JSON" && test -f "$MANIFEST_TXT"
' || fail "common-run.sh"

# ---- safety layer -------------------------------------------------------------
safe=$(bash --noprofile --norc -i -c '. ./common-safety.sh; umask; alias cp mv rm | sed "s/^alias //" | tr "\n" " "; set -o | grep noclobber | tr -s " \t" " "' 2>/dev/null)
case $safe in
    0077*"cp='cp -i'"*"mv='mv -i'"*"rm='rm -"[iI]"'"*"noclobber on"*) ;;
    *) fail "safety in bash -i: $safe" ;;
esac
base_umask=$(umask)
expect safe-off "$(UPH_SAFE=0 bash --noprofile --norc -i -c '. ./common-safety.sh; umask' 2>/dev/null)" "$base_umask"
expect safe-umask "$(UPH_UMASK=027 bash --noprofile --norc -i -c '. ./common-safety.sh; umask' 2>/dev/null)" 0027
expect safe-noninteractive "$(bash --noprofile --norc -c '. ./common-safety.sh; umask')" "$base_umask"
if have_zsh; then
    case $(zsh -f -i -c '. ./common-safety.sh; umask; alias cp' 2>/dev/null) in
        0077*"cp='cp -i'"|077*"cp='cp -i'") ;;
        *) fail "safety in zsh -i" ;;
    esac
fi

# ---- remote-setup.sh -----------------------------------------------------------
setup=./scripts/remote-setup.sh
printf 'export KEEP=1\n# user line\n' > "$HOME/.bashrc"
cp "$HOME/.bashrc" "$tmp/bashrc.orig"
expect status-initial "$($setup status | grep '^installed=')" installed=no
out=$($setup install --dry-run --from "$ROOT")
case $out in dry_run=1*) ;; *) fail "dry-run marker" ;; esac
cmp -s "$HOME/.bashrc" "$tmp/bashrc.orig" && [ ! -e "$HOME/.config/hpc" ] && [ ! -e "$HOME/.bashrc.uph-backup" ] ||
    fail "install --dry-run wrote something"
$setup install --from "$ROOT" >/dev/null
out=$($setup install --from "$ROOT")
case $out in *block=unchanged*) ;; *) fail "install not idempotent" ;; esac
expect block-count "$(grep -c '^# >>> unix-profile-helpers >>>$' "$HOME/.bashrc")" 1
cmp -s "$HOME/.bashrc.uph-backup" "$tmp/bashrc.orig" || fail "backup differs from original"
expect status-installed "$($setup status | grep -E '^(installed|up_to_date)=' | tr '\n' ' ')" "installed=yes up_to_date=yes "
# A clean interactive bash loads the helpers through the block.
loaded=$(bash --noprofile --norc -i -c '. "$HOME/.bashrc"; type hpcprofile >/dev/null && umask' 2>/dev/null)
expect bashrc-block-works "$loaded" 0077
out=$($setup uninstall)
case $out in *block=removed*) ;; *) fail "uninstall block" ;; esac
diff -q "$HOME/.bashrc" "$tmp/bashrc.orig" >/dev/null || fail "uninstall changed more than the block"
[ ! -e "$HOME/.config/hpc/common-slurm.sh" ] || fail "uninstall left files"
expect status-final "$($setup status | grep '^installed=')" installed=no
printf '# >>> unix-profile-helpers >>>\n' >> "$HOME/.bashrc"
$setup install --from "$ROOT" >/dev/null 2>&1 && fail "install accepted an unbalanced block"

# ---- install-font.sh -------------------------------------------------------------
out=$(./scripts/install-font.sh --dry-run)
case $out in
    *"would download https://github.com/JetBrains/JetBrainsMono/releases/"*) ;;
    *) fail "install-font --dry-run: $out" ;;
esac
[ ! -e "$HOME/.local" ] && [ ! -e "$HOME/Library" ] || fail "install-font --dry-run wrote files"
./scripts/install-font.sh --uninstall --dry-run >/dev/null || fail "install-font --uninstall --dry-run"

printf '%s\n' "HPC helper validation passed."
