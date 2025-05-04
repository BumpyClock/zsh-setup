#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# A robust installer for zsh, Oh My Zsh, popular plugins, Powerlevel10k,
# FiraCode Nerd Font, and lsd with corrected compinit and syntax-highlighting setup
# Supports macOS (Homebrew) and common Linux distros (apt, yum, dnf)
# Defaults to non-interactive (repeatable), use -i for interactive mode
# ----------------------------------------

# Colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Helper: prompt for yes/no
confirm() {
  read -r -p "$1 [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0;;
    *) return 1;;
  esac
}

# Ensure a command exists
require() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}Error:${NC} '$1' is required but not installed." >&2
    exit 1
  fi
}

# OS detection
ios_type="$(uname)"

# Install package via available manager
install_package() {
  pkg="$1"
  if [[ "$ios_type" == "Darwin" ]]; then
    brew install "$pkg"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y "$pkg"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$pkg"
  elif command -v yum &>/dev/null; then
    sudo yum install -y "$pkg"
  else
    echo -e "${YELLOW}Warning:${NC} Could not determine package manager for '$pkg'." >&2
  fi
}

# Parse flags
INTERACTIVE=false
while getopts "i" opt; do
  case "$opt" in
    i) INTERACTIVE=true ;; 
    *) echo "Usage: $0 [-i]" >&2; exit 1 ;;
  esac
done

# Starting message
if $INTERACTIVE; then
  echo -e "${GREEN}Interactive mode enabled${NC}"
  if ! confirm "This script will install Oh My Zsh, plugins, Powerlevel10k, FiraCode Nerd Font, and lsd. Continue?"; then
    echo "Cancelled."; exit 0
  fi
else
  echo -e "${GREEN}Running in non-interactive mode${NC}"
fi

# Ensure essential tools
require zsh || install_package zsh
require git
require curl

# Backup existing .zshrc
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
  timestamp=$(date +"%Y%m%d%H%M%S")
  cp "$ZSHRC" "$ZSHRC.backup.$timestamp"
  echo -e "${GREEN}Backed up ~/.zshrc to ~/.zshrc.backup.$timestamp${NC}"
fi

# Install Oh My Zsh
if [[ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  echo -e "${GREEN}Installing Oh My Zsh...${NC}"
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo -e "${GREEN}Oh My Zsh present; skipping.${NC}"
fi

# Custom folder
eval "export ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Plugin list
plugins=(zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-autocomplete)

# Clone plugins
for plugin in "${plugins[@]}"; do
  target="$ZSH_CUSTOM/plugins/$plugin"
  repo=""
  case "$plugin" in
    zsh-autosuggestions)       repo=https://github.com/zsh-users/zsh-autosuggestions.git;;
    zsh-syntax-highlighting)   repo=https://github.com/zsh-users/zsh-syntax-highlighting.git;;
    fast-syntax-highlighting)   repo=https://github.com/zdharma-continuum/fast-syntax-highlighting.git;;
    zsh-autocomplete)          repo=https://github.com/marlonrichert/zsh-autocomplete.git;;
  esac
  if [[ ! -d "$target" ]]; then
    echo -e "${GREEN}Installing $plugin...${NC}"
    git clone --depth 1 "$repo" "$target"
  fi
done

# Powerlevel10k theme
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  echo -e "${GREEN}Installing Powerlevel10k...${NC}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Update .zshrc: plugins and theme
if grep -qE '^plugins=' "$ZSHRC"; then
  sed -i.bak -E "s|^plugins=.*|plugins=(${plugins[*]})|" "$ZSHRC"
else
  echo "plugins=(${plugins[*]})" >> "$ZSHRC"
fi
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i.bak -E "s|^ZSH_THEME=.*|ZSH_THEME=\"powerlevel10k/powerlevel10k\"|" "$ZSHRC"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
fi

# Completion & highlighting setup
cat << 'EOF' >> "$ZSHRC"
# Clean up old compdump
rm -f ~/.zcompdump*

autoload -U compinit; compinit -u 2>/dev/null

# Syntax highlighting config
ZSH_HIGHLIGHT_STANDALONE=false
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
source "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "${ZSH_CUSTOM}/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

# lsd aliases
alias ls='lsd --long --group-directories-first'
alias ll='lsd -l --all --group-directories-first'
alias la='lsd -la --group-directories-first'
EOF

# Install FiraCode Nerd Font
if [[ "$ios_type" == "Darwin" ]]; then
  brew tap homebrew/cask-fonts && brew install --cask font-fira-code-nerd-font
elif command -v apt-get &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y fonts-firacode
else
  git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git /tmp/nerd-fonts && /tmp/nerd-fonts/install.sh --single 'FiraCode' && rm -rf /tmp/nerd-fonts
fi

# Install lsd
if ! command -v lsd &>/dev/null; then
  install_package lsd || { require cargo; cargo install lsd; }
fi

echo -e "${GREEN}Setup complete! Run 'exec zsh' or restart your terminal.${NC}"
