#!/bin/bash
# Deploy the shell helpers locally and, optionally, to a remote HPC login node.
#
#   ./deploy.sh                 local install, then offer the remote install
#   ./deploy.sh --remote-only   only the remote install
#
# Local: ~/.zshrc, ~/.config/zsh/{common-aliases.zsh,common-safety.sh,local.zsh}
# and ~/.config/hpc/common-profile.sh. Existing files are backed up first;
# local.zsh and profiles are never overwritten.
# Remote: scripts/remote-setup.sh over ssh (see README, "Remote helpers").
# Author: Maks Kliczkowski. License: MIT.

BOLD='\033[1m'; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_ONLY=false
FAILED=false
for arg in "$@"; do
    case $arg in
        -r|--remote|--remote-only) REMOTE_ONLY=true ;;
    esac
done

backup_file() {
    [[ -f "$1" ]] || return 0
    local backup="$1.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$1" "$backup" && echo -e "  - Backed up $(basename "$1") to ${YELLOW}$(basename "$backup")${NC}"
}

install_file() {   # install_file SRC DEST [MODE]
    backup_file "$2"
    cp "$1" "$2" && chmod "${3:-644}" "$2" && echo -e "  - ${CYAN}$2${NC}"
}

if [[ "$REMOTE_ONLY" == false ]]; then
    echo -e "${BOLD}[1/2] Local audit${NC}"
    echo "  - OS: $(uname -s)"
    [[ "$SHELL" == */zsh ]] || echo -e "  - ${YELLOW}Login shell is not Zsh ($SHELL); consider: chsh -s \$(command -v zsh)${NC}"
    [[ -d "$HOME/.oh-my-zsh" ]] && echo "  - Oh My Zsh: detected" || echo "  - Oh My Zsh: not installed (optional)"
    for tool in eza bat rg zoxide; do
        command -v "$tool" >/dev/null 2>&1 || echo -e "  - optional tool missing: ${YELLOW}$tool${NC}"
    done

    echo -e "${BOLD}[2/2] Local install${NC}"
    ZSH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
    HPC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hpc"
    mkdir -p "$ZSH_DIR" "$HPC_DIR/profiles"
    install_file "$SRC_DIR/zshrc" "$HOME/.zshrc"
    install_file "$SRC_DIR/common-aliases.zsh" "$ZSH_DIR/common-aliases.zsh"
    install_file "$SRC_DIR/common-safety.sh" "$ZSH_DIR/common-safety.sh"
    install_file "$SRC_DIR/common-profile.sh" "$HPC_DIR/common-profile.sh" 600
    if [[ ! -e "$ZSH_DIR/local.zsh" ]]; then
        cp "$SRC_DIR/local.zsh.example" "$ZSH_DIR/local.zsh" && chmod 600 "$ZSH_DIR/local.zsh"
        echo -e "  - created ${CYAN}$ZSH_DIR/local.zsh${NC}"
    fi
    if ! compgen -G "$HPC_DIR/profiles/*.sh" >/dev/null; then
        cp "$SRC_DIR/profiles/example.sh" "$HPC_DIR/profiles/example.sh" && chmod 600 "$HPC_DIR/profiles/example.sh"
        echo -e "  - created ${CYAN}$HPC_DIR/profiles/example.sh${NC}; copy it per cluster"
    fi
    echo -e "  ${GREEN}Local install complete.${NC} Optional font: scripts/install-font.sh"
fi

if [[ "$REMOTE_ONLY" == true ]]; then
    deploy_remote=y
else
    read -r -p "Install the helpers on a remote HPC login node? (y/N): " deploy_remote
fi

if [[ "$deploy_remote" == y || "$deploy_remote" == Y ]]; then
    read -r -p "  SSH address (user@host or ssh-config alias): " remote_host
    if [[ -z "$remote_host" ]]; then
        echo -e "  ${RED}Address cannot be empty.${NC}"
        FAILED=true
    else
        # Ignore interactive settings configured for an SSH host alias.
        SSH_OPTS=(-o RemoteCommand=none -o RequestTTY=no)

        read -r -p "  Authorize your local SSH public key for passwordless login? (y/N): " auth_ssh
        if [[ "$auth_ssh" == y || "$auth_ssh" == Y ]]; then
            read -r -p "  Public key file [$HOME/.ssh/id_ed25519.pub]: " key_file
            key_file="${key_file:-$HOME/.ssh/id_ed25519.pub}"
            key_file="${key_file/#\~/$HOME}"
            if [[ -f "$key_file" ]]; then
                ssh "${SSH_OPTS[@]}" "$remote_host" \
                    'mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" && cat >> "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"' \
                    < "$key_file" || echo -e "  ${RED}Key authorization failed; continuing.${NC}"
            else
                echo -e "  ${RED}Key not found: $key_file${NC}"
            fi
        fi

        # Stream the helpers to a temporary directory on the remote and run the
        # installer from there, so nothing needs to be cloned on the cluster.
        if tar -C "$SRC_DIR" -cf - common-profile.sh common-slurm.sh common-run.sh common-safety.sh scripts/remote-setup.sh |
            ssh "${SSH_OPTS[@]}" "$remote_host" \
                'd=$(mktemp -d) && tar -xf - -C "$d" && sh "$d/scripts/remote-setup.sh" install --from "$d"; rc=$?; rm -rf "$d"; exit $rc'
        then
            echo -e "  ${GREEN}Remote install complete.${NC} Profiles belong in ~/.config/hpc/profiles/"
        else
            echo -e "  ${RED}Remote install failed.${NC}"
            FAILED=true
        fi
    fi
fi

if [[ "$FAILED" == true ]]; then
    echo -e "${RED}${BOLD}Finished with errors.${NC}"
    exit 1
fi
echo -e "${GREEN}${BOLD}Done.${NC}"
[[ "$REMOTE_ONLY" == true ]] || echo "Reload with: exec zsh"
