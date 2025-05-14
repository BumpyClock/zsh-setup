#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# zsh-bootstrap.sh
# -----------------------------------------------------------------------------
# • Installs zsh (if missing), Oh‑My‑Zsh, Powerlevel10k, essential plugins,
#   FiraCode Nerd Font, and lsd.
# • Defaults to **non‑interactive**, fully repeatable. Use **-i** for a single
#   confirmation prompt.
# • Sets **zsh as the default login shell** automatically (or asks in -i mode).
# -----------------------------------------------------------------------------

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"

confirm() { read -r -p "$1 [y/N]: " ans; [[ $ans =~ ^([yY][eE][sS]|[yY])$ ]]; }
require() { command -v "$1" &>/dev/null || { echo -e "${RED}Error:${NC} $1 not found"; exit 1; }; }
install_pkg() {
  case $(uname) in
    Darwin) brew install "$1" ;;
    *)  if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y "$1";
        elif command -v dnf &>/dev/null;  then sudo dnf install -y "$1";
        elif command -v yum &>/dev/null;  then sudo yum install -y "$1";
        else echo -e "${YELLOW}Warn:${NC} manual install needed for $1"; fi ;;
  esac }

# -------------------------
# flags
# -------------------------
INTERACTIVE=false
while getopts "i" o; do [[ $o == i ]] && INTERACTIVE=true; done
$INTERACTIVE && { echo -e "${GREEN}Interactive mode${NC}"; confirm "Proceed with zsh bootstrap?" || exit 0; }

# -------------------------
# prerequisites
# -------------------------
require curl; require git; command -v zsh &>/dev/null || { echo "Installing zsh…"; install_pkg zsh; }

ZSHRC="$HOME/.zshrc"; [[ -f $ZSHRC ]] && cp "$ZSHRC" "${ZSHRC}.bak.$(date +%s)"

# -------------------------
# Oh My Zsh
# -------------------------
if [[ ! -d ${ZSH:-$HOME/.oh-my-zsh} ]]; then
  echo -e "${GREEN}Installing Oh My Zsh…${NC}"
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# -------------------------
# Plugins (minimal list for OMZ)
# -------------------------
OMZ_PLUGINS=(git zsh-autosuggestions zsh-autocomplete)
for p in zsh-autosuggestions zsh-autocomplete zsh-syntax-highlighting fast-syntax-highlighting; do
  dir="$ZSH_CUSTOM/plugins/$p"
  [[ -d $dir ]] || git clone --depth 1 "https://github.com/${p/zsh-/zsh-}.git" "$dir" &>/dev/null || true
done

# -------------------------
# Powerlevel10k theme
# -------------------------
[[ -d $ZSH_CUSTOM/themes/powerlevel10k ]] || git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" &>/dev/null

# -------------------------
# Write ~/.zshrc idempotently (plugin line and sentinel block)
# -------------------------
# 1. plugin list
if grep -qE "^plugins=" "$ZSHRC"; then
  sed -i.bak -E "s|^plugins=.*|plugins=(${OMZ_PLUGINS[*]})|" "$ZSHRC"
else
  echo "plugins=(${OMZ_PLUGINS[*]})" >> "$ZSHRC"
fi
# 2. theme line
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i.bak -E "s|^ZSH_THEME=.*|ZSH_THEME=\"powerlevel10k/powerlevel10k\"|" "$ZSHRC"
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
fi
# 3. managed block (remove old, then append)
sed -i.bak '/# <<< ZSH-BOOTSTRAP/{:a;n;/# >>> ZSH-BOOTSTRAP/!ba;d}' "$ZSHRC" || true
cat >> "$ZSHRC" << 'BLOCK'
# <<< ZSH-BOOTSTRAP (managed by zsh-bootstrap.sh; do not edit) >>>
# Clean stale completions then quiet‑init
rm -f ~/.zcompdump*
autoload -U compinit && compinit -u 2>/dev/null

# External highlighters (load **after** all other plugins)
source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
source "$ZSH_CUSTOM/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

# lsd modern ls aliases
if command -v lsd &>/dev/null; then
  alias ls='lsd --long --group-directories-first'
  alias ll='lsd -la --group-directories-first'
  alias la='lsd -a --group-directories-first'
fi
# >>> ZSH-BOOTSTRAP <<<
BLOCK

# -------------------------
# Fonts & tools
# -------------------------
case $(uname) in
  Darwin) brew tap homebrew/cask-fonts && brew install --cask font-fira-code-nerd-font ;;
  *)  if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y fonts-firacode || true; fi || {
        git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git /tmp/nerd-f && /tmp/nerd-f/install.sh --single FiraCode && rm -rf /tmp/nerd-f ; } ;;
esac

command -v lsd &>/dev/null || { echo "Installing lsd…"; install_pkg lsd || { require cargo; cargo install lsd; }; }

# -------------------------
# Make zsh the default shell (if not already)
# -------------------------
if [[ $SHELL != $(command -v zsh) ]]; then
  if $INTERACTIVE; then
    if confirm "Change default shell to zsh? (will prompt for password)"; then
      chsh -s "$(command -v zsh)" && echo -e "${GREEN}Default shell set to zsh.${NC}"
    else
      echo -e "${YELLOW}Skipped changing default shell.${NC}"
    fi
  else
    chsh -s "$(command -v zsh)" &>/dev/null || echo -e "${YELLOW}Could not change default shell automatically (requires password).${NC}"
  fi
fi

echo -e "${GREEN}Done!  ➜  Restart terminal or 'exec zsh'.${NC}"
