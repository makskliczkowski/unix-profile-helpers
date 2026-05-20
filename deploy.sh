#!/bin/bash

# ==============================================================================
# 🚀 Unix Profile Helpers Deployment & Configuration Tool
# ==============================================================================
# This script automates the deployment and updating of your highly-optimized
# Zsh and Slurm/HPC configurations across local machines and remote clusters.
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
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Title banner
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}     🚀 UNIX PROFILE HELPERS: LOCAL & REMOTE HPC DEPLOYER${NC}"
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo ""

# Get script execution directory
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------------------------
# 🕵️‍♂️ Step 1: Auditing System and Prerequisites
# ------------------------------------------------------------------------------
echo -e "${BLUE}${BOLD}[Step 1] Auditing local system and packages...${NC}"

# Detect OS
OS_TYPE=$(uname -s)
if [[ "$OS_TYPE" == "Darwin" ]]; then
    echo -e "  - Local OS: ${GREEN}macOS (Darwin)${NC}"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    echo -e "  - Local OS: ${GREEN}Linux${NC}"
else
    echo -e "  - Local OS: ${YELLOW}Unknown ($OS_TYPE)${NC}"
fi

# Check Shell
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
# 📓 Step 2: Auditing Obsidian Note Vault Pathing
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

# ------------------------------------------------------------------------------
# ⚙️ Step 3: Deploys Profile with Username Substitutions
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

# ------------------------------------------------------------------------------
# 🎛️ Step 4: Remote Cluster (Slurm) Configuration Setup
# ------------------------------------------------------------------------------
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}     🎛️ REMOTE SLURM SUPERCOMPUTER CONFIGURATOR${NC}"
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo ""

# Ask to deploy on cluster
read -p "Would you like to deploy the high-performance remote cluster environment (common-slurm.zsh) to a remote HPC supercomputer? (y/n): " deploy_remote

if [[ "$deploy_remote" == "y" || "$deploy_remote" == "Y" ]]; then
    echo ""
    echo -e "${BLUE}${BOLD}[Remote Config] Enter remote HPC credentials${NC}"
    echo -e "  ${YELLOW}Security Notice:${NC} This script operates entirely locally. No credentials or passwords"
    echo -e "  are saved. SSH password inputs occur directly via the standard secure SSH tunnel."
    echo ""
    
    read -p "  Enter remote cluster SSH address (e.g., user@cluster.hpc.edu or SSH Host alias): " remote_host
    if [[ -z "$remote_host" ]]; then
        echo -e "  ${RED}Error: Address cannot be empty. Skipping remote configuration...${NC}"
    else
        # 1. Authorize SSH Key (if requested)
        read -p "  Would you like to authorize your local SSH public key on this remote cluster for passwordless login? (y/n): " auth_ssh
        if [[ "$auth_ssh" == "y" || "$auth_ssh" == "Y" ]]; then
            # Find public keys
            local_pub_keys=($(find "$HOME/.ssh" -name "id_*.pub" 2>/dev/null))
            if [[ ${#local_pub_keys[@]} -eq 0 ]]; then
                echo -e "  ${RED}No local SSH public keys found in ~/.ssh. Skipping key copy...${NC}"
            else
                echo -e "  Available local public keys:"
                for i in "${!local_pub_keys[@]}"; do
                    echo -e "    [$i] $(basename "${local_pub_keys[$i]}")"
                done
                read -p "  Choose key to copy [default: 0]: " key_idx
                key_idx="${key_idx:-0}"
                selected_key="${local_pub_keys[$key_idx]}"
                
                if [[ -f "$selected_key" ]]; then
                    echo -e "  Copying $(basename "$selected_key") to remote cluster authorized_keys..."
                    echo -e "  ${YELLOW}Notice:${NC} You will be prompted for your remote cluster password now."
                    cat "$selected_key" | ssh "$remote_host" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
                    if [[ $? -eq 0 ]]; then
                        echo -e "  - SSH Public Key: ${GREEN}Authorized successfully!${NC}"
                    else
                        echo -e "  - ${RED}SSH Authorization failed. Remote setup will proceed with standard password prompts.${NC}"
                    fi
                else
                    echo -e "  ${RED}Invalid key selection. Skipping...${NC}"
                fi
            fi
        fi
        
        # 2. Copy the Slurm helpers
        echo ""
        echo -e "  Deploying POSIX-compatible ${CYAN}common-slurm.zsh${NC} to remote cluster..."
        echo -e "  ${YELLOW}Notice:${NC} You might be prompted for your password again."
        ssh "$remote_host" "mkdir -p ~/.config/hpc"
        scp "$SRC_DIR/common-slurm.zsh" "$remote_host":~/.config/hpc/common-slurm.sh
        
        if [[ $? -eq 0 ]]; then
            echo -e "  - Remote slurm config: ${GREEN}Successfully deployed!${NC}"
            
            # 3. Source it in remote shell profiles (.bashrc or .zshrc)
            echo -e "  Selecting target shell profile on cluster:"
            echo -e "    [1] .bashrc (Most remote clusters default to Bash)"
            echo -e "    [2] .zshrc  (If you run Zsh on cluster)"
            read -p "  Select shell profile index [default: 1]: " shell_idx
            shell_idx="${shell_idx:-1}"
            
            remote_profile="~/.bashrc"
            [[ "$shell_idx" == "2" ]] && remote_profile="~/.zshrc"
            
            echo -e "  Configuring remote auto-load inside ${CYAN}$remote_profile${NC}..."
            
            # Sourcing instructions block
            sourcing_block="\n# Load high-performance Slurm cluster shortcuts\nif [ -f \"\$HOME/.config/hpc/common-slurm.sh\" ]; then\n    source \"\$HOME/.config/hpc/common-slurm.sh\"\nfi\n"
            
            ssh "$remote_host" "grep -q 'common-slurm.sh' $remote_profile || echo -e '$sourcing_block' >> $remote_profile"
            if [[ $? -eq 0 ]]; then
                echo -e "  - Remote Auto-load: ${GREEN}Enabled successfully inside $remote_profile!${NC}"
            else
                echo -e "  - ${RED}Failed to automatically configure remote auto-load.${NC}"
                echo -e "    Please manually append this block inside your remote $remote_profile:"
                echo -e "    ${CYAN}if [ -f \"\$HOME/.config/hpc/common-slurm.sh\" ]; then source \"\$HOME/.config/hpc/common-slurm.sh\"; fi${NC}"
            fi
        else
            echo -e "  - ${RED}Failed to copy remote configuration files.${NC}"
        fi
    fi
fi

# ------------------------------------------------------------------------------
# 🎉 Completion
# ------------------------------------------------------------------------------
echo ""
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD}     🎉 CONGRATULATIONS! DEPLOYMENT SUCCESSFULLY COMPLETED!${NC}"
echo -e "${MAGENTA}${BOLD}====================================================================${NC}"
echo -e "  Reload your local active terminal session to apply the configs:"
echo -e "  ${CYAN}${BOLD}reloadzsh${NC} (or ${CYAN}${BOLD}exec zsh${NC})"
echo ""
