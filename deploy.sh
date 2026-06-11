#!/bin/bash

# ==============================================================================
# Unix Profile Helpers Deployment & Configuration Tool
# ==============================================================================
# Author: Maks Kliczkowski
# GitHub: makskliczkowski/unix-profile-helpers
# License: MIT
#
# This script automates the deployment and updating of highly-optimized
# Zsh and Slurm/HPC configurations across local machines and remote clusters.
# It just helps you set up local useful aliases and functions for your terminal, 
# and also helps you deploy
#
# Workflows:
#   - Detects system type (macOS / Linux)
#   - Audits local prerequisites (Oh My Zsh, eza, bat, ripgrep, etc.)
#   - Detects and customizes Obsidian Vault pathways
#   - Deploys Zsh profiles cleanly, substituting local home/user paths dynamically
#   - Manages automatic back-ups of existing configs
#   - Offers interactive deployment of remote cluster configs (common-slurm.zsh)
#   - Authorizes local public SSH keys on remote supercomputers securely
# ==============================================================================

# Colors for terminal styling
NC='\033[0m'            # No Color
BOLD='\033[1m'          # Bold text
RED='\033[0;31m'        # Red
BLUE='\033[0;34m'       # Blue
GREEN='\033[0;32m'      # Green
YELLOW='\033[1;33m'     # Yellow
MAGENTA='\033[0;35m'    # Magenta
CYAN='\033[0;36m'       # Cyan

# Title banner
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}         UNIX PROFILE HELPERS: LOCAL & REMOTE HPC DEPLOYER${NC}"
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "This script will help you set up your local "
echo -e "terminal environment with useful aliases and functions "
echo -e "and also deploy remote cluster configurations for HPC work."
echo -e "Author     : Maks Kliczkowski (GitHub: makskliczkowski)"
echo -e "License    : MIT"
echo -e "===================================================================="
echo -e "Have a nice day! \('-')/ \n"
echo ""

# Get script execution directory
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS
OS_TYPE=$(uname -s)

# Parse command line options - currently only supports --remote-only to skip local deployment
REMOTE_ONLY=false
DEPLOYMENT_FAILED=false
for arg in "$@"; do
    case $arg in
        -r|--remote|--remote-only)
            REMOTE_ONLY=true
            ;;
        *)
            # Ignore other options
            ;;
    esac
done

if [ "$REMOTE_ONLY" = false ]; then

# ------------------------------------------------------------------------------
# Step 1: Auditing System and Prerequisites
# ------------------------------------------------------------------------------

echo -e "${BLUE}${BOLD}[Step 1] Auditing local system and packages...${NC}"
if [[ "$OS_TYPE" == "Darwin" ]]; then
    echo -e "  - Local OS: ${GREEN}macOS (Darwin)${NC}"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo -e "  - Local OS: ${GREEN}Linux${NC}"
else
    echo -e "  - Local OS: ${YELLOW}Unknown ($OS_TYPE)${NC}"
fi

# Check Shell and see if it's Zsh
if [[ "$SHELL" != *"/zsh" ]]; then
    echo -e "  - ${YELLOW}Notice: Current login shell is not Zsh ($SHELL).${NC}"
    echo -e "    It is recommended to switch to Zsh using: chsh -s \$(which zsh)"
else
    echo -e "  - Shell: ${GREEN}Zsh detected${NC}"
fi

# Check Oh My Zsh
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    echo -e "  - ${YELLOW}Prerequisite Missing: Oh My Zsh is not installed at ~/.oh-my-zsh${NC}"
    echo -e "    You should install Oh My Zsh before continuing. Run:"
    echo -e "    ${CYAN}sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"${NC}"
    read -p "    Do you want to continue the profile deployment anyway? (y/n): " confirm_omz
    if [[ "$confirm_omz" != "y" && "$confirm_omz" != "Y" ]]; then
        echo -e "${RED}Deployment aborted.${NC}"
        exit 1
    fi
else
    echo -e "  - Oh My Zsh: ${GREEN}Detected at ~/.oh-my-zsh${NC}"
fi

# Audit Core CLI Tooling
echo -e "  - Auditing performance dependencies:"
PREREQS=(eza bat rg zoxide asdf juliaup)
MISSING_PREREQS=()
for tool in "${PREREQS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "    * $tool: ${GREEN}Installed${NC}"
    else
        echo -e "    * $tool: ${YELLOW}Missing${NC}"
        MISSING_PREREQS+=("$tool")
    fi
done

if [[ ${#MISSING_PREREQS[@]} -gt 0 ]]; then
    echo -e "  - ${YELLOW}Note: Some core diagnostic tools are missing: (${MISSING_PREREQS[*]}).${NC}"
    if [[ "$OS_TYPE" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        echo -e "    You can easily install them using Brew:"
        echo -e "    ${CYAN}brew install ${MISSING_PREREQS[*]}${NC}"
    else
        echo -e "    Please install them manually to enable all modular shell aliases."
    fi
fi
echo ""

# ------------------------------------------------------------------------------
# Step 2: Auditing Obsidian Note Vault Pathing
# ------------------------------------------------------------------------------

echo -e "${BLUE}${BOLD}[Step 2] Auditing Obsidian note-taking environment...${NC}"

OBSIDIAN_INSTALLED=false
OBSIDIAN_VAULT_PATH=""

# Check Obsidian application files
if [[ "$OS_TYPE" == "Darwin" ]]; then
    if [[ -d "/Applications/Obsidian.app" || -d "$HOME/Applications/Obsidian.app" ]]; then
        OBSIDIAN_INSTALLED=true
    fi
elif [[ "$OS_TYPE" == "Linux" ]]; then
    if command -v obsidian >/dev/null 2>&1 || [[ -d "$HOME/.var/app/md.obsidian.Obsidian" ]] || [[ -d "/var/lib/flatpak/app/md.obsidian.Obsidian" ]]; then
        OBSIDIAN_INSTALLED=true
    fi
fi

if [ "$OBSIDIAN_INSTALLED" = true ]; then
    echo -e "  - Obsidian: ${GREEN}Detected on your local machine.${NC}"
else
    echo -e "  - Obsidian: ${YELLOW}Not detected in default application paths.${NC}"
fi

if [ "$OBSIDIAN_INSTALLED" = true ]; then
    # Always prompt for the Vault Name (as requested)
    read -p "  Enter your Obsidian vault name [default: PhysicsNotes]: " vault_name
    vault_name="${vault_name:-PhysicsNotes}"

    DEFAULT_ICLOUD_VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/$vault_name"
    if [[ "$OS_TYPE" == "Darwin" && -d "$DEFAULT_ICLOUD_VAULT" ]]; then
        echo -e "  - Vault: ${GREEN}Default iCloud '$vault_name' vault detected!${NC}"
        OBSIDIAN_VAULT_PATH="$DEFAULT_ICLOUD_VAULT"
    else
        if [[ "$OS_TYPE" == "Darwin" ]]; then
            echo -e "  - Vault: Default iCloud '$vault_name' vault not found at:"
            echo -e "    $DEFAULT_ICLOUD_VAULT"
            read -p "    Use this default iCloud path anyway? (y/n) [default: y]: " use_icloud_anyway
            use_icloud_anyway="${use_icloud_anyway:-y}"
            if [[ "$use_icloud_anyway" == "y" || "$use_icloud_anyway" == "Y" ]]; then
                OBSIDIAN_VAULT_PATH="$DEFAULT_ICLOUD_VAULT"
            fi
        fi
        
        if [[ -z "$OBSIDIAN_VAULT_PATH" ]]; then
            read -p "    Please enter the absolute path to your Obsidian vault '$vault_name' (or press Enter to skip configuring vault aliases): " user_vault
            if [[ -n "$user_vault" ]]; then
                # Expand ~ if entered
                user_vault="${user_vault/#\~/$HOME}"
                if [[ -d "$user_vault" ]]; then
                    echo -e "    Vault configured to: ${GREEN}$user_vault${NC}"
                    OBSIDIAN_VAULT_PATH="$user_vault"
                else
                    echo -e "    ${RED}Directory not found. Skipping vault configuration...${NC}"
                fi
            fi
        fi
    fi
    echo ""
else
    echo -e "  - ${YELLOW}Skipping vault path configuration since Obsidian is not detected.${NC}"
    echo -e "    You can still configure vault aliases manually later by editing ~/.config/zsh/common-aliases.zsh"
    echo -e "    and replacing the default vault path with your custom path.${NC}"
    echo ""
fi

# ------------------------------------------------------------------------------
# Step 3: Deploys Profile with Username Substitutions
# ------------------------------------------------------------------------------

echo -e "${BLUE}${BOLD}[Step 3] Deploys local shell profile...${NC}"

# Backup helper function
backup_file() {
    local target_file="$1"
    if [[ -f "$target_file" ]]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local backup_name="${target_file}.backup.${timestamp}"
        echo -e "  - Existing $(basename "$target_file") detected! Backing up to: ${YELLOW}$(basename "$backup_name")${NC}"
        cp "$target_file" "$backup_name"
    fi
}

# 1. Deploy main zshrc
backup_file "$HOME/.zshrc"

echo -e "  - Deploying customized ${CYAN}~/.zshrc${NC} (resolving home directory placeholders...)"
# Substitute __HOME__ with actual $HOME path dynamically
sed "s|__HOME__|$HOME|g" "$SRC_DIR/zshrc" > "$HOME/.zshrc"
echo -e "    ${GREEN}Success!${NC} ~/.zshrc written."

# 2. Deploy common configurations
CONF_DIR="$HOME/.config/zsh"
mkdir -p "$CONF_DIR"

backup_file "$CONF_DIR/common-aliases.zsh"
backup_file "$CONF_DIR/common-hpc.zsh"

LOCAL_CONFIG="$CONF_DIR/local.zsh"
if [[ ! -e "$LOCAL_CONFIG" ]]; then
    echo -e "  - Creating machine-specific settings at ${CYAN}$LOCAL_CONFIG${NC}"
    sed "s|__HOME__|$HOME|g" "$SRC_DIR/local.zsh.example" > "$LOCAL_CONFIG"
    chmod 600 "$LOCAL_CONFIG"
else
    echo -e "  - Preserving existing machine-specific settings at ${CYAN}$LOCAL_CONFIG${NC}"
fi

echo -e "  - Deploying general aliases to ${CYAN}$CONF_DIR/common-aliases.zsh${NC}"
# Copy general aliases directly
cp "$SRC_DIR/common-aliases.zsh" "$CONF_DIR/common-aliases.zsh"

# Customize vault path inside common-aliases.zsh if customized path exists
if [[ -n "$OBSIDIAN_VAULT_PATH" ]]; then
    echo -e "  - Injecting Obsidian vault directory..."
    # Escape path for sed substitution
    escaped_vault=$(echo "$OBSIDIAN_VAULT_PATH" | sed 's/[&/]/\\&/g')
    # Replace default iCloud path with user's customized path
    sed -i.bak "s|\$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes|$escaped_vault|g" "$CONF_DIR/common-aliases.zsh" 2>/dev/null || \
    sed -i "" "s|\$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/PhysicsNotes|$escaped_vault|g" "$CONF_DIR/common-aliases.zsh"
    rm -f "$CONF_DIR/common-aliases.zsh.bak"
fi

echo -e "  - Deploying local HPC manager to ${CYAN}$CONF_DIR/common-hpc.zsh${NC}"
cp "$SRC_DIR/common-hpc.zsh" "$CONF_DIR/common-hpc.zsh"

echo -e "  - ${GREEN}Local deployment successfully complete!${NC}"
echo ""
fi

# ------------------------------------------------------------------------------
# Step 4: Remote Cluster (Slurm) Configuration Setup
# ------------------------------------------------------------------------------
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}        REMOTE SLURM SUPERCOMPUTER CONFIGURATOR${NC}"
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo ""

# Ask to deploy on cluster
if [ "$REMOTE_ONLY" = true ]; then
    deploy_remote="y"
else
    read -p "Would you like to deploy the high-performance remote cluster environment (common-slurm.zsh) to a remote HPC supercomputer? (y/n): " deploy_remote
fi

if [[ "$deploy_remote" == "y" || "$deploy_remote" == "Y" ]]; then
    echo ""
    echo -e "${BLUE}${BOLD}[Remote Config] Enter remote HPC credentials${NC}"
    echo -e "  ${YELLOW}Security Notice:${NC} This script operates entirely locally. No credentials or passwords"
    echo -e "  are saved. SSH password inputs occur directly via the standard secure SSH tunnel."
    echo ""
    
    read -p "  Enter remote cluster SSH address (e.g., user@cluster.hpc.edu or SSH Host alias): " remote_host
    
    if [[ -z "$remote_host" ]]; then
        echo -e "  ${RED}Error: Address cannot be empty. Remote configuration failed.${NC}"
        DEPLOYMENT_FAILED=true
    else
        # Ignore interactive settings configured for an SSH host alias.
        SSH_COMMAND_OPTIONS=(-o RemoteCommand=none -o RequestTTY=no)

        # 1. Authorize SSH Key (if requested)
        read -p "  Would you like to authorize your local SSH public key on this remote cluster for passwordless login? (y/n): " auth_ssh
        if [[ "$auth_ssh" == "y" || "$auth_ssh" == "Y" ]]; then
            # Find public keys
            local_pub_keys=($(find "$HOME/.ssh" -name "id_*.pub" 2>/dev/null))
            selected_key=""
            
            if [[ ${#local_pub_keys[@]} -eq 0 ]]; then
                echo -e "  - ${YELLOW}No public keys found automatically in ~/.ssh${NC}"
                read -p "  Please enter the absolute path to your public SSH key (or press Enter to skip SSH key authorization): " manual_key
                if [[ -n "$manual_key" ]]; then
                    manual_key="${manual_key/#\~/$HOME}"
                    if [[ -f "$manual_key" ]]; then
                        selected_key="$manual_key"
                    else
                        echo -e "  ${RED}Key file not found at: $manual_key. Skipping SSH authorization...${NC}"
                    fi
                fi
            else
                echo -e "  Available local public keys:"
                for i in "${!local_pub_keys[@]}"; do
                    echo -e "    [$i] $(basename "${local_pub_keys[$i]}") (${local_pub_keys[$i]})"
                done
                
                read -p "  Enter public key index to copy, or enter the absolute path to a custom public key [default: 0]: " key_input
                key_input="${key_input:-0}"
                
                if [[ "$key_input" =~ ^[0-9]+$ ]] && [[ "$key_input" -lt ${#local_pub_keys[@]} ]]; then
                    selected_key="${local_pub_keys[$key_input]}"
                elif [[ -n "$key_input" ]]; then
                    # Try to treat input as a path
                    key_input="${key_input/#\~/$HOME}"
                    if [[ -f "$key_input" ]]; then
                        selected_key="$key_input"
                    else
                        echo -e "  ${RED}No valid key index or key file found at: $key_input. Skipping SSH authorization...${NC}"
                    fi
                else
                    echo -e "  ${RED}No input provided. Skipping SSH key authorization...${NC}"
                fi
            fi
            
            if [[ -n "$selected_key" && -f "$selected_key" ]]; then
                echo -e "  Copying $(basename "$selected_key") to remote cluster authorized_keys..."
                echo -e "  ${YELLOW}Notice:${NC} You will be prompted for your remote cluster password now."
                cat "$selected_key" | ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" \
                    'mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" && cat >> "$HOME/.ssh/authorized_keys" && chmod 600 "$HOME/.ssh/authorized_keys"'
                if [[ $? -eq 0 ]]; then
                    echo -e "  - SSH Public Key: ${GREEN}Authorized successfully!${NC}"
                else
                    echo -e "  - ${RED}SSH Authorization failed. Remote setup will proceed with standard password prompts.${NC}"
                fi
            fi
        fi
        
        # 2. Copy the Slurm helpers
        echo ""
        echo -e "  Deploying Bash/Zsh-compatible ${CYAN}common-slurm.zsh${NC} to remote cluster..."
        echo -e "  ${YELLOW}Notice:${NC} You might be prompted for your password again."
        if ! ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" 'mkdir -p "$HOME/.config/hpc"'; then
            echo -e "  - ${RED}Failed to create the remote configuration directory.${NC}"
            DEPLOYMENT_FAILED=true
        elif ! scp "${SSH_COMMAND_OPTIONS[@]}" "$SRC_DIR/common-slurm.zsh" "$remote_host:.config/hpc/common-slurm.sh.new"; then
            echo -e "  - ${RED}Failed to copy remote configuration files.${NC}"
            DEPLOYMENT_FAILED=true
        elif ! ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" '
            set -e
            helper="$HOME/.config/hpc/common-slurm.sh"
            incoming="${helper}.new"
            bash -n "$incoming"
            if command -v zsh >/dev/null 2>&1; then
                zsh -n "$incoming"
            fi
            if [ -f "$helper" ]; then
                cp -p "$helper" "${helper}.backup"
            fi
            mv "$incoming" "$helper"
            chmod 600 "$helper"
            if [ ! -e "$HOME/.config/hpc/local.sh" ]; then
                printf "%s\n" \
                    "# Per-cluster overrides for common-slurm.sh" \
                    "# UPH_SLURM_PARTITION=normal" \
                    "# UPH_SLURM_ACCOUNT=my-project" \
                    "# UPH_GPU_TYPE=a100" \
                    "# UPH_GPU_DEVEL_PARTITION=dgx" \
                    "# UPH_GPU_DEVEL_QOS=devel" \
                    "# UPH_MODULE_SLURM=slurm" \
                    "# UPH_PC2_PROJECT=hpc-prf-example" \
                    "# UPH_SCRATCH_DIR=\$PC2PFS/\$UPH_PC2_PROJECT" \
                    "# UPH_MODULE_COMPILER=GCC/13.2.0" \
                    "# UPH_MODULE_MPI=OpenMPI/4.1.6" \
                    "# UPH_MODULE_HDF5=HDF5/1.14.3" \
                    "# UPH_MODULE_PYTHON=Python/3.11" \
                    "# UPH_MODULE_JULIA=lang/JuliaHPC" \
                    "# UPH_MODULE_CONTAINER=system/Apptainer" \
                    "# UPH_MODULE_BLAS=OpenBLAS/0.3.26" \
                    "# UPH_MODULE_BOOST=Boost/1.84.0" \
                    "# UPH_MODULE_NETCDF=netCDF/4.9.2" \
                    > "$HOME/.config/hpc/local.sh"
                chmod 600 "$HOME/.config/hpc/local.sh"
            fi
        '; then
            echo -e "  - Remote slurm config: ${RED}Validation or activation failed.${NC}"
            DEPLOYMENT_FAILED=true
        else
            echo -e "  - Remote slurm config: ${GREEN}Validated and deployed successfully!${NC}"
            
            # 3. Source it in remote shell profiles (.bashrc or .zshrc)
            echo -e "  Selecting target shell profile on cluster:"
            echo -e "    [1] .bashrc (Most remote clusters default to Bash)"
            echo -e "    [2] .zshrc  (If you run Zsh on cluster)"
            read -p "  Select shell profile index [default: 1]: " shell_idx
            shell_idx="${shell_idx:-1}"
            
            remote_profile_name=".bashrc"
            [[ "$shell_idx" == "2" ]] && remote_profile_name=".zshrc"
            remote_profile="~/$remote_profile_name"
            
            echo -e "  Configuring remote auto-load inside ${CYAN}$remote_profile${NC}..."
            
            # Sourcing instructions block
            sourcing_block="\n# Load high-performance Slurm cluster shortcuts\nif [ -f \"\$HOME/.config/hpc/common-slurm.sh\" ]; then\n    . \"\$HOME/.config/hpc/common-slurm.sh\"\nfi\n"
            
            if printf '%b' "$sourcing_block" | ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" \
                "target=\"\$HOME/$remote_profile_name\"; touch \"\$target\" && { grep -Fq 'common-slurm.sh' \"\$target\" || cat >> \"\$target\"; }"; then
                echo -e "  - Remote Auto-load: ${GREEN}Enabled successfully inside $remote_profile!${NC}"
                remote_shell="bash"
                [[ "$shell_idx" == "2" ]] && remote_shell="zsh"
                if ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" "
                    $remote_shell -c '. \"\$HOME/.config/hpc/common-slurm.sh\"; type inter >/dev/null 2>&1; type hpchelp >/dev/null 2>&1'
                "; then
                    echo -e "  - Remote helper check: ${GREEN}inter and hpchelp are available.${NC}"
                    echo -e "  - Cluster overrides: ${CYAN}~/.config/hpc/local.sh${NC}"
                    if ! ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" 'command -v srun >/dev/null 2>&1'; then
                        echo -e "  - ${YELLOW}Warning: srun was not found in a non-interactive login.${NC}"
                        echo -e "    Run ${CYAN}hpcdoctor${NC} after logging in to inspect the cluster environment."
                    fi
                else
                    DEPLOYMENT_FAILED=true
                    echo -e "  - ${RED}Remote helper verification failed in $remote_shell.${NC}"
                fi
            else
                DEPLOYMENT_FAILED=true
                echo -e "  - ${RED}Failed to automatically configure remote auto-load.${NC}"
                echo -e "    Please manually append this block inside your remote $remote_profile:"
                echo -e "    ${CYAN}if [ -f \"\$HOME/.config/hpc/common-slurm.sh\" ]; then . \"\$HOME/.config/hpc/common-slurm.sh\"; fi${NC}"
            fi
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 🎉 Completion
# ------------------------------------------------------------------------------
echo ""
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
if [ "$DEPLOYMENT_FAILED" = true ]; then
    echo -e "${RED}${BOLD}                    DEPLOYMENT FAILED${NC}"
else
    echo -e "${GREEN}${BOLD}            DEPLOYMENT SUCCESSFULLY COMPLETED!${NC}"
fi
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
if [ "$REMOTE_ONLY" = false ]; then
    echo -e "  Reload your local active terminal session to apply the configs:"
    echo -e "  ${CYAN}${BOLD}reloadzsh${NC} (or ${CYAN}${BOLD}exec zsh${NC})"
fi
echo ""

[ "$DEPLOYMENT_FAILED" = false ]
