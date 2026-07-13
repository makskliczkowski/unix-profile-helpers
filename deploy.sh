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
#   - Offers interactive deployment of remote cluster configs (common-slurm.zsh, common-run.sh)
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

# Check optional Oh My Zsh installation.
OMZ_DIR="$HOME/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    echo -e "  - Oh My Zsh: ${YELLOW}Not installed (optional; plain Zsh remains supported)${NC}"
else
    echo -e "  - Oh My Zsh: ${GREEN}Detected at ~/.oh-my-zsh${NC}"
fi

# Audit optional CLI tooling.
echo -e "  - Auditing optional command-line tools:"
OPTIONAL_TOOLS=(eza bat rg zoxide asdf juliaup)
MISSING_OPTIONAL_TOOLS=()
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "    * $tool: ${GREEN}Installed${NC}"
    else
        echo -e "    * $tool: ${YELLOW}Missing${NC}"
        MISSING_OPTIONAL_TOOLS+=("$tool")
    fi
done

if [[ ${#MISSING_OPTIONAL_TOOLS[@]} -gt 0 ]]; then
    echo -e "  - ${YELLOW}Optional tools not found: (${MISSING_OPTIONAL_TOOLS[*]}).${NC}"
    echo -e "    The profile will use fallbacks or omit the related integration."
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

read -p "  Configure the optional Obsidian helpers now? (y/N): " configure_obsidian
if [[ "$configure_obsidian" == "y" || "$configure_obsidian" == "Y" ]]; then
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
    echo -e "  - Obsidian helpers remain disabled. Set OBSIDIAN_VAULT in ${XDG_CONFIG_HOME:-$HOME/.config}/zsh/local.zsh to enable them later."
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

echo -e "  - Deploying portable ${CYAN}~/.zshrc${NC}..."
cp "$SRC_DIR/zshrc" "$HOME/.zshrc"
echo -e "    ${GREEN}Success!${NC} ~/.zshrc written."

# 2. Deploy common configurations
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
mkdir -p "$CONF_DIR"

backup_file "$CONF_DIR/common-aliases.zsh"
backup_file "$CONF_DIR/common-hpc.zsh"

LOCAL_CONFIG="$CONF_DIR/local.zsh"
if [[ ! -e "$LOCAL_CONFIG" ]]; then
    echo -e "  - Creating machine-specific settings at ${CYAN}$LOCAL_CONFIG${NC}"
    cp "$SRC_DIR/local.zsh.example" "$LOCAL_CONFIG"
    chmod 600 "$LOCAL_CONFIG"
else
    echo -e "  - Preserving existing machine-specific settings at ${CYAN}$LOCAL_CONFIG${NC}"
fi

echo -e "  - Deploying general aliases to ${CYAN}$CONF_DIR/common-aliases.zsh${NC}"
# Copy general aliases directly
cp "$SRC_DIR/common-aliases.zsh" "$CONF_DIR/common-aliases.zsh"

# Store the selected vault in the machine-specific file. Shared helpers stay
# identical across macOS and Linux deployments.
if [[ -n "$OBSIDIAN_VAULT_PATH" ]]; then
    if grep -Eq '^[[:space:]]*(export[[:space:]]+)?OBSIDIAN_VAULT=' "$LOCAL_CONFIG"; then
        echo -e "  - Preserving existing OBSIDIAN_VAULT in ${CYAN}$LOCAL_CONFIG${NC}"
    else
        echo -e "  - Saving Obsidian vault in ${CYAN}$LOCAL_CONFIG${NC}"
        printf '\nexport OBSIDIAN_VAULT=%q\n' "$OBSIDIAN_VAULT_PATH" >> "$LOCAL_CONFIG"
    fi
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
    read -p "Would you like to deploy the high-performance remote cluster environment (common-slurm.zsh) to a remote HPC supercomputer? (y/N): " deploy_remote
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
        read -p "  Would you like to authorize your local SSH public key on this remote cluster for passwordless login? (y/N): " auth_ssh
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
        
        # 2. Copy the remote HPC helpers
        echo ""
        echo -e "  Deploying Bash/Zsh-compatible ${CYAN}common-slurm.zsh${NC} and ${CYAN}common-run.sh${NC} to remote cluster..."
        echo -e "  ${YELLOW}Notice:${NC} You might be prompted for your password again."
        if ! ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" 'mkdir -p "$HOME/.config/hpc"'; then
            echo -e "  - ${RED}Failed to create the remote configuration directory.${NC}"
            DEPLOYMENT_FAILED=true
        elif ! scp "${SSH_COMMAND_OPTIONS[@]}" "$SRC_DIR/common-slurm.zsh" "$remote_host:.config/hpc/common-slurm.sh.new"; then
            echo -e "  - ${RED}Failed to copy remote configuration files.${NC}"
            DEPLOYMENT_FAILED=true
        elif ! scp "${SSH_COMMAND_OPTIONS[@]}" "$SRC_DIR/common-run.sh" "$remote_host:.config/hpc/common-run.sh.new"; then
            echo -e "  - ${RED}Failed to copy remote run helper.${NC}"
            DEPLOYMENT_FAILED=true
        elif ! ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" '
            set -e
            slurm_helper="$HOME/.config/hpc/common-slurm.sh"
            slurm_incoming="${slurm_helper}.new"
            run_helper="$HOME/.config/hpc/common-run.sh"
            run_incoming="${run_helper}.new"
            bash -n "$slurm_incoming"
            bash -n "$run_incoming"
            if command -v zsh >/dev/null 2>&1; then
                zsh -n "$slurm_incoming"
            fi
            if [ -f "$slurm_helper" ]; then
                cp -p "$slurm_helper" "${slurm_helper}.backup"
            fi
            if [ -f "$run_helper" ]; then
                cp -p "$run_helper" "${run_helper}.backup"
            fi
            mv "$slurm_incoming" "$slurm_helper"
            mv "$run_incoming" "$run_helper"
            chmod 600 "$slurm_helper" "$run_helper"
            if [ ! -e "$HOME/.config/hpc/local.sh" ]; then
                printf "%s\n" \
                    "# Per-cluster overrides for common-slurm.sh" \
                    "# This file is local-only and preserved by deploy.sh." \
                    "# UPH_SLURM_PARTITION=normal" \
                    "# UPH_SLURM_ACCOUNT=my-project" \
                    "# UPH_SLURM_QOS=normal" \
                    "# UPH_SLURM_CPUS=4" \
                    "# UPH_SLURM_TIME=01:00:00" \
                    "# UPH_SLURM_MEMORY=4G" \
                    "# UPH_SLURM_GRES=gpu:1" \
                    "# UPH_INTERACTIVE_SHELL=/bin/bash" \
                    "# UPH_QUOTA_GROUP=my-project" \
                    "# UPH_MODULE_SLURM=slurm" \
                    "# UPH_SCRATCH_DIR=/path/to/project/scratch" \
                    "# UPH_PROJECT_NAME=hpc-project" \
                    "# UPH_MODULE_COMPILER=compiler-module" \
                    "# UPH_MODULE_MPI=mpi-module" \
                    "# UPH_MODULE_HDF5=hdf5-module" \
                    "# UPH_MODULE_PYTHON=python-module" \
                    "# UPH_MODULE_JULIA=julia-module" \
                    "# UPH_MODULE_CMAKE=cmake-module" \
                    "# UPH_MODULE_CONTAINER=Apptainer" \
                    "# UPH_MODULE_BLAS=blas-module" \
                    "# UPH_MODULE_BOOST=boost-module" \
                    "# UPH_MODULE_NETCDF=netcdf-module" \
                    > "$HOME/.config/hpc/local.sh"
                chmod 600 "$HOME/.config/hpc/local.sh"
            else
                echo "Preserving existing $HOME/.config/hpc/local.sh"
            fi
        '; then
            echo -e "  - Remote slurm config: ${RED}Validation or activation failed.${NC}"
            DEPLOYMENT_FAILED=true
        else
            echo -e "  - Remote HPC helpers: ${GREEN}Validated and deployed successfully!${NC}"
            
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
            sourcing_block="\n# Load high-performance Slurm and run-directory helpers\nif [ -f \"\$HOME/.config/hpc/common-slurm.sh\" ]; then\n    . \"\$HOME/.config/hpc/common-slurm.sh\"\nfi\nif [ -f \"\$HOME/.config/hpc/common-run.sh\" ]; then\n    . \"\$HOME/.config/hpc/common-run.sh\"\nfi\n"
            
            if printf '%b' "$sourcing_block" | ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" \
                "target=\"\$HOME/$remote_profile_name\"; touch \"\$target\" && { grep -Fq 'common-slurm.sh' \"\$target\" && grep -Fq 'common-run.sh' \"\$target\" || cat >> \"\$target\"; }"; then
                echo -e "  - Remote Auto-load: ${GREEN}Enabled successfully inside $remote_profile!${NC}"
                remote_shell="bash"
                [[ "$shell_idx" == "2" ]] && remote_shell="zsh"
                if ssh "${SSH_COMMAND_OPTIONS[@]}" "$remote_host" "
                    $remote_shell -c '. \"\$HOME/.config/hpc/common-slurm.sh\"; [ -f \"\$HOME/.config/hpc/common-run.sh\" ] && . \"\$HOME/.config/hpc/common-run.sh\"; type inter >/dev/null 2>&1; type hpchelp >/dev/null 2>&1; type uph_make_run_dir >/dev/null 2>&1'
                "; then
                    echo -e "  - Remote helper check: ${GREEN}inter, hpchelp, and uph_make_run_dir are available.${NC}"
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
                echo -e "    ${CYAN}if [ -f \"\$HOME/.config/hpc/common-run.sh\" ]; then . \"\$HOME/.config/hpc/common-run.sh\"; fi${NC}"
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
