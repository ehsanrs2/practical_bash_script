#!/usr/bin/env bash
#
# Ubuntu Dev Setup Script
# - Installs zsh, oh-my-zsh
# - Installs popular plugins (autosuggestions, syntax-highlighting, completions, fzf, autojump)
# - Installs Powerlevel10k theme
# - Sets zsh as default shell
#
# Run:  chmod +x ubuntu_dev_setup.sh && ./ubuntu_dev_setup.sh
#

set -e

### ---- Configurable section (in case you want to tweak later) ---- ###

OMZ_PLUGINS=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf
  autojump
)

ZSH_THEME_NAME="powerlevel10k/powerlevel10k"

### ---- Helpers ---- ###

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Command '$1' not found but is required."
    exit 1
  fi
}

### ---- Check OS ---- ###

if ! command -v lsb_release >/dev/null 2>&1; then
  warn "lsb_release not found. Skipping OS check (should be Ubuntu)."
else
  DISTRO=$(lsb_release -is 2>/dev/null || echo "")
  if [ "$DISTRO" != "Ubuntu" ]; then
    warn "This script is optimized for Ubuntu, detected: $DISTRO"
  fi
fi

### ---- Install base packages ---- ###

info "Updating apt and installing base packages..."

sudo apt update

sudo apt install -y \
  zsh git curl wget \
  fzf autojump \
  fonts-powerline \
  build-essential \
  htop tree \
  ripgrep fd-find \
  neovim

# Some Ubuntu versions call fd 'fdfind'
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  info "Creating alias 'fd' for 'fdfind'"
  sudo update-alternatives --install /usr/local/bin/fd fd "$(command -v fdfind)" 10 || true
fi

### ---- Install Oh My Zsh ---- ###

if [ -d "$HOME/.oh-my-zsh" ]; then
  info "Oh My Zsh already installed. Skipping installation."
else
  info "Installing Oh My Zsh (unattended)..."
  # Keep existing .zshrc if any; no auto-chsh, no auto-run zsh
  export RUNZSH="no"
  export CHSH="no"
  export KEEP_ZSHRC="yes"

  /usr/bin/env sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

### ---- Install plugins ---- ###

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

install_or_update_git_repo() {
  local repo_url="$1"
  local dest_dir="$2"

  if [ -d "$dest_dir/.git" ]; then
    info "Updating $(basename "$dest_dir")..."
    git -C "$dest_dir" pull --ff-only || warn "Could not update $(basename "$dest_dir")"
  elif [ -d "$dest_dir" ]; then
    warn "$dest_dir exists but is not a git repo. Skipping."
  else
    info "Cloning $(basename "$dest_dir")..."
    git clone --depth=1 "$repo_url" "$dest_dir"
  fi
}

info "Installing Oh My Zsh plugins..."

install_or_update_git_repo \
  https://github.com/zsh-users/zsh-autosuggestions.git \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

install_or_update_git_repo \
  https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

install_or_update_git_repo \
  https://github.com/zsh-users/zsh-completions.git \
  "$ZSH_CUSTOM/plugins/zsh-completions"

### ---- Install Powerlevel10k theme ---- ###

info "Installing Powerlevel10k theme..."

install_or_update_git_repo \
  https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k"

### ---- Optional: Install Meslo Nerd Fonts (for Powerlevel10k) ---- ###

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

MESLO_URL_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
MESLO_FONTS=(
  "MesloLGS NF Regular.ttf"
  "MesloLGS NF Bold.ttf"
  "MesloLGS NF Italic.ttf"
  "MesloLGS NF Bold Italic.ttf"
)

for font in "${MESLO_FONTS[@]}"; do
  DEST="$FONT_DIR/$font"
  if [ ! -f "$DEST" ]; then
    info "Downloading font: $font"
    wget -qO "$DEST" "$MESLO_URL_BASE/${font// /%20}" || warn "Failed to download $font"
  else
    info "Font already exists: $font"
  fi
done

fc-cache -fv >/dev/null 2>&1 || true

### ---- Auto-set Meslo Nerd Font in GNOME Terminal ---- ###

info "Trying to configure GNOME Terminal font automatically..."

if command -v gsettings >/dev/null 2>&1; then
    # Detect GNOME Terminal profiles
    PROFILE_LIST=$(gsettings get org.gnome.Terminal.ProfilesList list | tr -d "[]',")
    DEFAULT_PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

    if [ -z "$DEFAULT_PROFILE" ]; then
        warn "GNOME Terminal default profile not detected. Skipping font auto-setup."
    else
        info "Detected GNOME Terminal profile: $DEFAULT_PROFILE"
        FONT_NAME="MesloLGS NF Regular 12"

        # Apply to default profile
        gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$DEFAULT_PROFILE/" use-system-font false
        gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$DEFAULT_PROFILE/" font "$FONT_NAME"

        info "GNOME Terminal font has been set to: $FONT_NAME"
    fi
else
    warn "gsettings not found. Cannot auto-configure GNOME Terminal font."
fi


### ---- Configure ~/.zshrc ---- ###

ZSHRC="$HOME/.zshrc"

if [ ! -f "$ZSHRC" ]; then
  info "No ~/.zshrc found. Creating a new one from Oh My Zsh template."
  cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
fi

info "Configuring ~/.zshrc ..."

# Set theme
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"$ZSH_THEME_NAME\"|" "$ZSHRC"
else
  echo "ZSH_THEME=\"$ZSH_THEME_NAME\"" >> "$ZSHRC"
fi

# Set plugins
PLUGINS_LINE="plugins=(${OMZ_PLUGINS[*]})"
if grep -q '^plugins=' "$ZSHRC"; then
  sed -i "s/^plugins=.*/$PLUGINS_LINE/" "$ZSHRC"
else
  echo "$PLUGINS_LINE" >> "$ZSHRC"
fi

# Ensure fpath for zsh-completions
if ! grep -q 'zsh-completions' "$ZSHRC"; then
  cat << 'EOF' >> "$ZSHRC"

# zsh-completions
if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions" ]; then
  fpath=(${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions/src $fpath)
fi
EOF
fi

# Ensure zsh-syntax-highlighting is sourced at the end
if ! grep -q 'zsh-syntax-highlighting.zsh' "$ZSHRC"; then
  cat << 'EOF' >> "$ZSHRC"

# zsh-syntax-highlighting must be last
if [ -f "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
EOF
fi

# Ensure autojump init (if installed)
if ! grep -q 'autojump.zsh' "$ZSHRC"; then
  cat << 'EOF' >> "$ZSHRC"

# autojump init (if installed)
if [ -f /usr/share/autojump/autojump.zsh ]; then
  . /usr/share/autojump/autojump.zsh
fi
EOF
fi

### ---- Set zsh as default shell ---- ###

if [ "$SHELL" != "$(command -v zsh)" ]; then
  info "Changing default shell to zsh..."
  require_cmd chsh
  chsh -s "$(command -v zsh)" "$USER" || warn "Could not change shell automatically. You may need to run: chsh -s $(which zsh)"
else
  info "zsh is already the default shell."
fi

info "All done! Log out and log back in (or open a new terminal) to start using zsh + Oh My Zsh + plugins + Powerlevel10k."

