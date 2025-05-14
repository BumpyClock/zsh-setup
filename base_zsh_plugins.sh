#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# zsh-bootstrap.sh  —  repeatable & idempotent
# -----------------------------------------------------------------------------
# Installs / configures:
#   • zsh (if missing) + makes it default shell
#   • Oh‑My‑Zsh
#   • Powerlevel10k theme
#   • Core plugins: git, zsh‑autosuggestions, zsh‑autocomplete, fast‑syntax‑highlighting
#   • eza (modern ls)  ➜  with smart aliases
#   • FiraCode Nerd Font (icons)
#   • Leaves user tweaks in ~/.zshrc intact (merges plugin list, appends a tail block)
# Use `-i` for a single interactive confirmation prompt.
# -----------------------------------------------------------------------------
GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
confirm() { read -r -p "$1 [y/N]: " a; [[ $a =~ ^([yY](es)?|[yY])$ ]]; }
require() { command -v "$1" &>/dev/null || { echo -e "${RED}Error:${NC} $1 not installed"; exit 1; }; }
install_pkg() {
  case $(uname) in
    Darwin) brew install "$1" ;;
    *) if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y "$1";
       elif command -v dnf &>/dev/null; then sudo dnf install -y "$1";
       elif command -v yum &>/dev/null; then sudo yum install -y "$1";
       else echo -e "${YELLOW}Warn:${NC} install $1 manually"; fi ;;
  esac }

# ----------------------- flags -----------------------
INTERACTIVE=false
while getopts "i" o; do [[ $o == i ]] && INTERACTIVE=true; done
$INTERACTIVE && { echo -e "${GREEN}Interactive mode${NC}"; confirm "Run zsh bootstrap?" || exit 0; }

# -------------------- prerequisites ------------------
require curl; require git; command -v zsh &>/dev/null || { echo "Installing zsh…"; install_pkg zsh; }

ZSHRC="$HOME/.zshrc"; [[ -f $ZSHRC ]] && cp "$ZSHRC" "${ZSHRC}.bak.$(date +%s)"

touch "$ZSHRC"   # guarantee file exists

# 0️⃣  quiet Powerlevel10k & OMZ compfix once
sed -i '/POWERLEVEL9K_INSTANT_PROMPT/d' "$ZSHRC"
sed -i '1itypeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet' "$ZSHRC"
sed -i '/ZSH_DISABLE_COMPFIX/d' "$ZSHRC"
sed -i '1iexport ZSH_DISABLE_COMPFIX=true' "$ZSHRC"

# 1️⃣  Oh‑My‑Zsh --------------------------------------------------------------
if [[ ! -d ${ZSH:-$HOME/.oh-my-zsh} ]]; then
  echo -e "${GREEN}Installing Oh‑My‑Zsh…${NC}"
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# 2️⃣  Clone plugins / theme ---------------------------------------------------
CORE_PLUGINS=(git zsh-autosuggestions zsh-autocomplete)
EXTRA_REPOS=( zsh-autosuggestions zsh-autocomplete fast-syntax-highlighting )
for r in "${EXTRA_REPOS[@]}"; do d="$ZSH_CUSTOM/plugins/$r"; [[ -d $d ]] || git clone --depth 1 "https://github.com/${r/zsh-/zsh-}.git" "$d" &>/dev/null || true; done
[[ -d $ZSH_CUSTOM/themes/powerlevel10k ]] || git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" &>/dev/null

# 3️⃣  Merge plugin list -------------------------------------------------------
if grep -q '^plugins=' "$ZSHRC"; then
  current=$(grep '^plugins=' "$ZSHRC" | sed -E 's/plugins=\((.*)\)/\1/')
  read -r -a arr <<< "$current"
  for p in "${CORE_PLUGINS[@]}"; do [[ " ${arr[*]} " =~ " $p " ]] || arr+=("$p"); done
  sed -i -E "0,/^plugins=/{s|^plugins=.*|plugins=(${arr[*]})|}" "$ZSHRC"
else
  echo "plugins=(${CORE_PLUGINS[*]})" >> "$ZSHRC"
fi

# 4️⃣  Theme if missing --------------------------------------------------------
grep -q '^ZSH_THEME=' "$ZSHRC" || echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"

# 5️⃣  Tail block (idempotent) -------------------------------------------------
sed -i '/# <<< ZSH-BOOTSTRAP/{:a;n;/# >>> ZSH-BOOTSTRAP/!ba;d}' "$ZSHRC" || true
cat >> "$ZSHRC" << 'BLOCK'
# <<< ZSH-BOOTSTRAP (managed) >>>
# prune vendor completions that cause compinit warnings
fpath=( ${fpath:#/usr/share/zsh/vendor-completions} )
rm -f ~/.zcompdump*
autoload -U compinit && compinit -u 2>/dev/null
# fast syntax-highlighting (after compinit)
FAST_HL="$ZSH_CUSTOM/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
[[ -f $FAST_HL ]] && source "$FAST_HL"
# eza aliases
if command -v eza &>/dev/null; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -la --icons=auto --git --group-directories-first'
  alias la='eza -a --icons=auto --group-directories-first'
fi
# >>> ZSH-BOOTSTRAP <<<
BLOCK

# 6️⃣  FiraCode Nerd Font ------------------------------------------------------
case $(uname) in
  Darwin) brew tap homebrew/cask-fonts && brew install --cask font-fira-code-nerd-font ;;
  *) if command -v apt-get &>/dev/null; then sudo apt-get update && sudo apt-get install -y fonts-firacode || true; fi || {
       git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git /tmp/nerdf && /tmp/nerdf/install.sh --single FiraCode && rm -rf /tmp/nerdf; } ;;
esac

# 7️⃣  Install eza -------------------------------------------------------------
command -v eza &>/dev/null || { echo "Installing eza…"; install_pkg eza || { require cargo; cargo install eza; }; }

# 8️⃣  Default shell -----------------------------------------------------------
if [[ $SHELL != $(command -v zsh) ]]; then
  if $INTERACTIVE; then confirm "Set zsh as default shell?" && chsh -s "$(command -v zsh)"; else chsh -s "$(command -v zsh)" &>/dev/null || echo -e "${YELLOW}Could not change default shell automatically.${NC}"; fi
fi

echo -e "${GREEN}✔ zsh-bootstrap complete — restart or 'exec zsh'.${NC}"
