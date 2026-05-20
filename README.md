# Unix Profile Helpers (High-Performance Zsh Configuration)

A curated, highly-optimized macOS/Unix shell configuration featuring instant shell startup, advanced alias systems, helpful utilities, and an on-demand Anaconda/Miniforge lazy loader.

---

## 🚀 Performance Overview

On macOS, sourcing large environment manager initialization scripts (such as Anaconda or Miniforge) synchronously on shell startup is a major bottleneck—often adding **1.4s to 2.0s** of latency per terminal tab because of compiler wrapper checks (`_tc_activation`). 

This setup resolves that issue by utilizing a **custom lazy loader for Conda**. Shell startup time is reduced to **~0.15s - 0.25s (an 11x speedup)**, while the `conda` command remains fully functional and automatically initializes the environment the first time it is called.

---

## 📦 What's Inside

1. **`zshrc`**: The core profile configuration file containing Oh My Zsh settings, active plugin lists, theme choices (`agnoster`), paths, and the Python/Conda lazy loader.
2. **`common-aliases.zsh`**: A highly organized, modular aliases and helper functions file. It defines standard navigation shortcuts, modern utility aliases (e.g. `eza`, `bat`, `ripgrep`), archive extractors, safe network transfer utilities, and a custom search/interactive helper system (`mkhelp`).

---

## 🛠️ Prerequisites & Tools to Install

To get the most out of this configuration, install the following modern CLI tools on a new computer.

### 1. Core Tooling via Homebrew
Ensure [Homebrew](https://brew.sh/) is installed, then run:
```bash
brew install eza bat ripgrep zoxide asdf juliaup
```
*   `eza`: A modern, feature-rich replacement for `ls` (used for `l`, `ll`, `la` aliases).
*   `bat`: A `cat` clone with syntax highlighting and Git integration.
*   `ripgrep` (`rg`): An extremely fast search tool (used to replace `grep`).
*   `zoxide`: A smarter `cd` command.
*   `asdf`: Multiple runtime version manager.
*   `juliaup`: Julia installer and version manager.

### 2. Oh My Zsh
Install Oh My Zsh:
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 3. Zsh Custom Plugins
This profile depends on several powerful syntax and completion plugins. Clone them to your Oh My Zsh custom plugins folder:

```bash
# zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# zsh-completions
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions

# zsh-history-substring-search
git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

# fast-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

---

## ⚙️ New Machine Deployment Steps

Follow these steps to deploy this configuration on a new machine:

### Step 1: Copy the Configuration Files
1. **Zsh Main Profile**: Copy the `zshrc` file in this repository to your home directory as `.zshrc`.
   ```bash
   cp zshrc ~/.zshrc
   ```
2. **Common Aliases Folder**: Create the target `.config/zsh` directory and copy the `common-aliases.zsh` file into it.
   ```bash
   mkdir -p ~/.config/zsh
   cp common-aliases.zsh ~/.config/zsh/common-aliases.zsh
   ```

### Step 2: Edit Path & Username Variables (CRITICAL)
Since paths contain machine-specific usernames and directory layouts, open both files and make the following changes:

#### In `~/.zshrc`:
*   **Username in Paths**: Locate and replace all instances of `/Users/makskliczkowski` with your new local home directory path (e.g. `/Users/yourusername` or `$HOME`).
*   **Simulation & Libraries Paths** (Lines 145-150): Update or comment out the paths for your custom toolchain libraries if they don't apply to the new machine:
    ```zsh
    export ARMADILLO_INCL_DIR=/Users/yourusername/libraries/armadillo-14.0.2/include
    export QES_PYPATH=/Users/yourusername/Codes/QuantumEigenSolver/pyqusolver/Python
    export QES_PYPATH_GEN_PYTHON=/Users/yourusername/Codes/QuantumEigenSolver/pyqusolver/Python/QES/general_python
    export QES_SLURMPATH=/Users/yourusername/Codes/QuantumEigenSolver/slurm
    ```
*   **Juliaup Path**: Update the `.juliaup` path:
    ```zsh
    path=('/Users/yourusername/.juliaup/bin' $path)
    ```
*   **Conda Lazy Loader Paths** (Lines 119-127): If you installed Miniconda or Miniforge in a non-standard location on your new computer, make sure the activate paths in the lazy loader match your new system:
    ```zsh
    if [[ -f "/opt/homebrew/Caskroom/miniforge/base/bin/activate" ]]; then ...
    ```

#### In `~/.config/zsh/common-aliases.zsh`:
*   **Jump Shortcuts**: Update any project shortcuts to reflect your new projects workspace directory:
    ```zsh
    alias codes='cd ~/Codes'
    alias pyqusolver='cd ~/Codes/QuantumEigenSolver/pyqusolver'
    ```
*   **Obsidian / iCloud Vault Path** (Line 12 & Line 128): Adjust the iCloud/Obsidian vault paths or remove them if you don't sync markdown vaults via iCloud:
    ```zsh
    alias mkobsidian='cd ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/PhysicsNotes'
    ```

### Step 3: Refresh the Shell Session
Activate the changes by running:
```bash
reloadzsh
```
*(Or use `exec zsh`)*

---

## 💡 Custom Commands & Helper Functions

### 1. `mkhelp`
Type `mkhelp` in your terminal to see a clean, interactive summary of your custom configuration, files, loaded totals, active plugins, and quick-access descriptions of your custom aliases. Run `mkhelp all` to output the full live-shell inventory.

### 2. `rscp` (Unified rsync Wrapper)
A safe, robust command to transfer files securely with progress indicator and directory cleanup:
```bash
rscp [--rm] [-p PORT] <src> <dst>
```
*   `--rm`: Safely removes source files and cleans up empty directories after successful copy (converts the command into a robust move).

### 3. `extract`
Easily extract common archive formats (`.zip`, `.tar.gz`, `.xz`, `.7z`, `.rar`, etc.) without remembering different tar or unzip flags:
```bash
extract filename.tar.gz
```

### 4. `mkcd`
Create a directory and immediately change into it:
```bash
mkcd path/to/new-directory
```
