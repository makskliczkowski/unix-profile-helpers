#!/bin/sh
# Install the small helper subset on a login node, or remove it again.
#
#   remote-setup.sh install|uninstall|status [--dry-run] [--from DIR]
#
# install copies common-profile.sh, common-slurm.sh, common-run.sh and
# common-safety.sh from DIR (default: the repository) to ~/.config/hpc/ and
# keeps ONE marked block in ~/.bashrc that sources them. It is idempotent: a
# re-run replaces the block in place. ~/.bashrc is copied once to
# ~/.bashrc.uph-backup before the first change. uninstall removes exactly that
# block and those files; profiles, the backup and the rest of ~/.bashrc stay.
# --dry-run reports the same key=value lines without writing anything.
# Output is one key=value per line so that a caller can parse it.
# Needs only sh, sed, awk, cmp, grep and cp; no sudo.
set -eu

start='# >>> unix-profile-helpers >>>'
end='# <<< unix-profile-helpers <<<'
files="common-profile.sh common-slurm.sh common-run.sh common-safety.sh"
dest=$HOME/.config/hpc
bashrc=$HOME/.bashrc
backup=$HOME/.bashrc.uph-backup

usage() { echo "usage: remote-setup.sh install|uninstall|status [--dry-run] [--from DIR]" >&2; exit 2; }

[ $# -ge 1 ] || usage
cmd=$1; shift
dry=0
from=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
while [ $# -gt 0 ]; do
    case $1 in
        --dry-run) dry=1 ;;
        --from) [ $# -ge 2 ] || usage; from=$2; shift ;;
        *) usage ;;
    esac
    shift
done
case $cmd in install|uninstall|status) ;; *) usage ;; esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

say() { printf '%s=%s\n' "$1" "$2"; }
die() { printf 'remote-setup: %s\n' "$*" >&2; exit 1; }

# A block with a missing half would make the awk filters eat the rest of the
# file, so refuse to touch an unbalanced ~/.bashrc.
nstart=0 nend=0
if [ -e "$bashrc" ]; then
    nstart=$(grep -cxF "$start" "$bashrc" || true)
    nend=$(grep -cxF "$end" "$bashrc" || true)
fi
[ "$nstart" = "$nend" ] && [ "$nstart" -le 1 ] ||
    die "$bashrc has an unbalanced or duplicated unix-profile-helpers block; fix it by hand"

# Write $1 to ~/.bashrc, after a one-time backup of the original.
write_bashrc() {
    if [ -e "$bashrc" ] && [ ! -e "$backup" ]; then
        [ "$dry" = 1 ] || cp -p "$bashrc" "$backup"
        say backup created
    else
        say backup "$([ -e "$backup" ] && echo exists || echo none)"
    fi
    [ "$dry" = 1 ] || cat "$1" > "$bashrc"
}

if [ "$cmd" = status ]; then
    say dir "$dest"
    say bashrc "$bashrc"
    say block "$([ "$nstart" = 1 ] && echo present || echo absent)"
    say backup "$([ -e "$backup" ] && echo present || echo absent)"
    present=0 current=yes
    for f in $files; do
        if [ -f "$dest/$f" ]; then
            present=$((present + 1)); say "file.$f" present
            cmp -s "$from/$f" "$dest/$f" 2>/dev/null || current=no
        else
            say "file.$f" missing; current=no
        fi
        [ -f "$from/$f" ] || current=unknown
    done
    if [ "$nstart" = 1 ] && [ "$present" -eq 4 ]; then installed=yes
    elif [ "$nstart" = 0 ] && [ "$present" -eq 0 ]; then installed=no
    else installed=partial; fi
    say installed "$installed"
    say up_to_date "$current"
    exit 0
fi

[ "$dry" = 1 ] && say dry_run 1

if [ "$cmd" = install ]; then
    for f in $files; do
        [ -r "$from/$f" ] || die "missing source file: $from/$f"
    done
    for f in $files; do
        if cmp -s "$from/$f" "$dest/$f" 2>/dev/null; then
            say "file.$f" unchanged
        else
            if [ "$dry" = 0 ]; then
                mkdir -p "$dest"
                cp "$from/$f" "$dest/$f.new" && chmod 600 "$dest/$f.new" && mv "$dest/$f.new" "$dest/$f"
            fi
            say "file.$f" installed
        fi
    done

    cat > "$tmp/block" <<EOF
$start
# Managed by remote-setup.sh; "remote-setup.sh uninstall" removes it.
[ -r "\$HOME/.config/hpc/common-safety.sh" ] && . "\$HOME/.config/hpc/common-safety.sh"
[ -r "\$HOME/.config/hpc/common-slurm.sh" ] && . "\$HOME/.config/hpc/common-slurm.sh"
$end
EOF
    if [ "$nstart" = 1 ]; then
        awk -v s="$start" -v e="$end" -v blockfile="$tmp/block" '
            $0 == s { while ((getline line < blockfile) > 0) print line; skip = 1; next }
            $0 == e && skip { skip = 0; next }
            !skip { print }' "$bashrc" > "$tmp/new"
        action=replaced
    else
        { [ ! -s "$bashrc" ] || cat "$bashrc"; } > "$tmp/new"
        # Keep the block on its own line when the file lacks a final newline.
        [ ! -s "$tmp/new" ] || [ -z "$(tail -c1 "$tmp/new")" ] || echo >> "$tmp/new"
        cat "$tmp/block" >> "$tmp/new"
        action=added
    fi
    if [ -e "$bashrc" ] && cmp -s "$tmp/new" "$bashrc"; then
        say block unchanged
    else
        write_bashrc "$tmp/new"
        say block "$action"
    fi
else
    if [ "$nstart" = 1 ]; then
        awk -v s="$start" -v e="$end" '
            $0 == s { skip = 1; next }
            $0 == e && skip { skip = 0; next }
            !skip { print }' "$bashrc" > "$tmp/new"
        write_bashrc "$tmp/new"
        say block removed
    else
        say block absent
    fi
    for f in $files; do
        if [ -f "$dest/$f" ]; then
            [ "$dry" = 1 ] || rm -f "$dest/$f"
            say "file.$f" removed
        else
            say "file.$f" absent
        fi
    done
    [ "$dry" = 1 ] || rmdir "$dest" 2>/dev/null || true
fi
