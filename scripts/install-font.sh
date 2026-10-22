#!/bin/sh
# Install a free monospace terminal font for the current user, no sudo.
#
#   install-font.sh [--dry-run] [--uninstall] [--version VER] [--sha256 HASH]
#
# Font: JetBrains Mono (SIL Open Font License 1.1), downloaded over https from
# the official GitHub release. The project publishes no checksum file, so the
# SHA-256 of the download is printed; pass --sha256 to require a match.
# Linux: ~/.local/share/fonts/jetbrains-mono, then fc-cache.
# macOS: ~/Library/Fonts/jetbrains-mono.
# Re-running with the same version does nothing. Needs curl or wget, and unzip.
set -eu

version=2.304
dry=0 uninstall=0 want_sha=""
while [ $# -gt 0 ]; do
    case $1 in
        --dry-run) dry=1 ;;
        --uninstall) uninstall=1 ;;
        --version) version=${2:?--version needs a value}; shift ;;
        --sha256) want_sha=${2:?--sha256 needs a value}; shift ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'install-font: unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

case $(uname -s) in
    Darwin) dest=$HOME/Library/Fonts/jetbrains-mono ;;
    *) dest=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/jetbrains-mono ;;
esac
url=https://github.com/JetBrains/JetBrainsMono/releases/download/v$version/JetBrainsMono-$version.zip
marker=$dest/.uph-version

refresh_cache() {
    if [ "$(uname -s)" != Darwin ] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$dest" 2>/dev/null || fc-cache -f
    fi
}

if [ "$uninstall" = 1 ]; then
    if [ ! -d "$dest" ]; then
        printf 'not installed: %s\n' "$dest"
    elif [ "$dry" = 1 ]; then
        printf 'would remove %s\n' "$dest"
    else
        rm -rf -- "$dest"
        refresh_cache
        printf 'removed %s\n' "$dest"
    fi
    exit 0
fi

if [ -r "$marker" ] && [ "$(cat "$marker")" = "$version" ]; then
    printf 'already installed: JetBrains Mono %s in %s\n' "$version" "$dest"
    exit 0
fi

if [ "$dry" = 1 ]; then
    printf 'would download %s\n' "$url"
    [ -z "$want_sha" ] || printf 'would require sha256 %s\n' "$want_sha"
    printf 'would install fonts/ttf/*.ttf into %s\n' "$dest"
    exit 0
fi

command -v unzip >/dev/null 2>&1 || { echo "install-font: unzip is required" >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' -o "$tmp/font.zip" "$url"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$tmp/font.zip" "$url"
else
    echo "install-font: curl or wget is required" >&2; exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    got=$(sha256sum "$tmp/font.zip" | awk '{ print $1 }')
else
    got=$(shasum -a 256 "$tmp/font.zip" | awk '{ print $1 }')
fi
printf 'sha256 %s\n' "$got"
if [ -n "$want_sha" ] && [ "$got" != "$want_sha" ]; then
    printf 'install-font: checksum mismatch, expected %s\n' "$want_sha" >&2
    exit 1
fi

unzip -q -j "$tmp/font.zip" 'fonts/ttf/*.ttf' -d "$tmp/ttf"
mkdir -p "$dest"
cp "$tmp"/ttf/*.ttf "$dest"/
printf '%s\n' "$version" > "$marker"
refresh_cache
printf 'installed JetBrains Mono %s in %s\nSet the terminal font to "JetBrains Mono".\n' "$version" "$dest"
