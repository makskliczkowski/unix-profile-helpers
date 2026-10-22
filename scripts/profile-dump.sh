#!/usr/bin/env bash
# Print a profile as tab-separated key/base64(value) lines.
# This is the stable interface consumed by shub and other tools. The shell
# helpers source profiles directly, so both consumers share one schema.
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HPC_PROFILE_DIR="${HPC_PROFILE_DIR:-$here/profiles}"
export HPC_PROFILE_DIR
HPC_PROFILE_AUTOLOAD=0
# shellcheck source=../common-profile.sh
. "$here/common-profile.sh"

name=${1:-${HPC_PROFILE:-default}}
hpc_profile_load "$name"

emit() {
    printf '%s\t' "$1"
    printf '%s' "${2-}" | base64 | tr -d '\n'
    printf '\n'
}

emit HPC_PROFILE "$HPC_PROFILE"
emit HPC_PROFILE_FILE "$HPC_PROFILE_FILE"
emit HPC_PROFILE_RUN "$HPC_PROFILE_RUN"
for key in $_hpc_profile_scalars; do
    eval "emit \"\$key\" \"\${$key-}\""
done
for key in $_hpc_profile_arrays; do
    eval "set -- \${$key[@]+\"\${$key[@]}\"}"
    for value in "$@"; do
        emit "$key" "$value"
    done
done

# Preserve extension HPC_* keys that are not part of the core schema. shub
# writes them back when a profile is edited instead of silently dropping them.
_known=" $(printf '%s %s %s' "$_hpc_profile_scalars" "$_hpc_profile_arrays" "HPC_PROFILE HPC_PROFILE_FILE HPC_PROFILE_RUN HPC_PROFILE_DIR HPC_PROFILE_AUTOLOAD" | tr '\n' ' ') "
while IFS= read -r _key; do
    [ -n "$_key" ] || continue
    case "$_known" in
        *" $_key "*) continue ;;
    esac
    if declare -p "$_key" 2>/dev/null | grep -q 'declare -a'; then
        eval "set -- \${$_key[@]+\"\${$_key[@]}\"}"
        for _value in "$@"; do
            emit "$_key" "$_value"
        done
    else
        eval "emit \"\$_key\" \"\${$_key-}\""
    fi
done < <(compgen -A variable HPC_ | sort)
unset _known _key _value
