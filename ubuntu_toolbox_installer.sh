#!/usr/bin/env bash
#
# Ubuntu Toolbox Installer
#
# Features:
#   1) Install Oh My Zsh
#      - If ubuntu_dev_setup.sh exists in the same directory, use it.
#   2) Install virtualenvwrapper
#      - If setup_python_virtualenvwrapper.sh exists in the same directory, use it.
#   3) Install Google Chrome
#   4) Install Conda (Miniconda)
#   5) Install VS Code + "Open in VS Code" context menu
#      - Dolphin (KDE)
#      - Nautilus (GNOME Files)
#   6) Install Dolphin File Manager
#   7) Install NVIDIA GPU drivers (nvidia-smi)
#
# Usage:
#   chmod +x ubuntu_toolbox_installer.sh
#   ./ubuntu_toolbox_installer.sh
#

set -e

# ---------- Helper functions ----------

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Command '$1' not found but is required."
    exit 1
  fi
}

status_label() {
  if [ "$1" = "yes" ]; then
    echo "[installed]"
  else
    echo "[        ]"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Detect installed ----------

is_installed_ohmyzsh() {
  [[ -d "$HOME/.oh-my-zsh" ]]
}

is_installed_virtualenvwrapper() {
  command -v virtualenvwrapper.sh >/dev/null 2>&1
}

is_installed_chrome() {
  command -v google-chrome >/dev/null 2>&1 || \
  command -v google-chrome-stable >/dev/null 2>&1
}

is_installed_conda() {
  command -v conda >/dev/null 2>&1 || [[ -d "$HOME/miniconda3" ]]
}

is_installed_vscode() {
  command -v code >/dev/null 2>&1
}

is_installed_dolphin() {
  command -v dolphin >/dev/null 2>&1
}

is_installed_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1
}

# ---------- Installers ----------

install_ohmyzsh() {
  if is_installed_ohmyzsh; then
    info "Oh My Zsh is already installed. Skipping."
    return
  fi

  # Use your existing dev-setup script if available
  if [[ -x "$SCRIPT_DIR/ubuntu_dev_setup.sh" ]]; then
    info "Running ubuntu_dev_setup.sh for Oh My Zsh and extra setup..."
    "$SCRIPT_DIR/ubuntu_dev_setup.sh"
    return
  fi

  info "Installing minimal Oh My Zsh..."

  sudo apt update
  sudo apt install -y zsh git curl fonts-powerline

  export RUNZSH="no"
  export CHSH="no"
  export KEEP_ZSHRC="yes"

  /usr/bin/env sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  info "Oh My Zsh installed. You can customize themes and plugins later."
}

install_virtualenvwrapper() {
  if is_installed_virtualenvwrapper; then
    info "virtualenvwrapper is already installed. Skipping."
    return
  fi

  # Use your full setup script if available
  if [[ -x "$SCRIPT_DIR/setup_python_virtualenvwrapper.sh" ]]; then
    info "Running setup_python_virtualenvwrapper.sh ..."
    "$SCRIPT_DIR/setup_python_virtualenvwrapper.sh"
    return
  fi

  info "Installing minimal Python + virtualenvwrapper..."

  sudo apt update
  sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential

  # Ensure python -> python3
  if ! command -v python >/dev/null 2>&1; then
    sudo apt install -y python-is-python3 || true
  fi

  sudo pip3 install --upgrade pip
  sudo pip3 install --upgrade virtualenv virtualenvwrapper

  VIRTUALENV_BIN=$(command -v virtualenv || true)
  VIRTUALENVWRAPPER_SH=$(command -v virtualenvwrapper.sh || true)
  if [ -z "$VIRTUALENV_BIN" ]; then
    error "virtualenv command not found after installation."
  fi

  if [ -z "$VIRTUALENVWRAPPER_SH" ]; then
    if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
      VIRTUALENVWRAPPER_SH=/usr/local/bin/virtualenvwrapper.sh
    elif [ -f /usr/bin/virtualenvwrapper.sh ]; then
      VIRTUALENVWRAPPER_SH=/usr/bin/virtualenvwrapper.sh
    else
      error "virtualenvwrapper.sh not found."
    fi
  fi

  WORKON_HOME="$HOME/.virtualenvs"
  PYTHON3_PATH="$(command -v python3)"
  mkdir -p "$WORKON_HOME"

  VENV_BLOCK="
# >>> virtualenvwrapper configuration >>>
export WORKON_HOME=\"$WORKON_HOME\"
export VIRTUALENVWRAPPER_PYTHON=\"$PYTHON3_PATH\"
export VIRTUALENVWRAPPER_VIRTUALENV=\"$VIRTUALENV_BIN\"
if [ -f \"$VIRTUALENVWRAPPER_SH\" ]; then
    source \"$VIRTUALENVWRAPPER_SH\"
fi
# <<< virtualenvwrapper configuration <<<
"

  add_block_if_missing() {
    local file="$1"
    local marker="virtualenvwrapper configuration"

    if [ ! -f "$file" ]; then
      touch "$file"
    fi

    if grep -q "$marker" "$file"; then
      info "virtualenvwrapper config is already present in $file. Skipping."
    else
      info "Adding virtualenvwrapper config to $file"
      printf "\n%s\n" "$VENV_BLOCK" >> "$file"
    fi
  }

  add_block_if_missing "$HOME/.bashrc"
  add_block_if_missing "$HOME/.zshrc"

  # Pre-init to avoid first-run console output in shells (for Powerlevel10k instant prompt)
  info "Pre-initializing virtualenvwrapper..."
  env \
    WORKON_HOME="$WORKON_HOME" \
    VIRTUALENVWRAPPER_PYTHON="$PYTHON3_PATH" \
    VIRTUALENVWRAPPER_VIRTUALENV="$VIRTUALENV_BIN" \
    bash -lc "source \"$VIRTUALENVWRAPPER_SH\" >/dev/null 2>&1" || \
    warn "virtualenvwrapper pre-init failed, but it should still work."

  info "virtualenvwrapper installed and configured."
}

install_chrome() {
  if is_installed_chrome; then
    info "Google Chrome is already installed. Skipping."
    return
  fi

  info "Installing Google Chrome..."

  TMP_DEB="/tmp/google-chrome-stable_current_amd64.deb"
  wget -qO "$TMP_DEB" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  sudo apt install -y "$TMP_DEB"
  rm -f "$TMP_DEB"

  info "Google Chrome installed."
}

install_conda() {
  if is_installed_conda; then
    info "Conda/Miniconda already installed. Skipping."
    return
  fi

  info "Installing Miniconda (Conda) into \$HOME/miniconda3 ..."

  CONDA_DIR="$HOME/miniconda3"
  INSTALLER="/tmp/miniconda.sh"

  wget -qO "$INSTALLER" "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  bash "$INSTALLER" -b -p "$CONDA_DIR"
  rm -f "$INSTALLER"

  "$CONDA_DIR/bin/conda" init bash || true
  "$CONDA_DIR/bin/conda" init zsh || true

  info "Miniconda installed. Open a new shell to use 'conda'."
}

configure_vscode_context_menu() {
  if ! is_installed_vscode; then
    warn "VS Code is not installed yet, but context menu entries will be prepared."
  fi

  info "Adding 'Open in VS Code' to Dolphin context menu..."

  # Dolphin service menu
  SERVICE_DIR="$HOME/.local/share/kservices5/ServiceMenus"
  mkdir -p "$SERVICE_DIR"

  cat > "$SERVICE_DIR/vscode_dolphin.desktop" << 'EOF'
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin
MimeType=inode/directory;inode/mount-point;application/x-iso;application/octet-stream;text/plain;application/x-shellscript;
Actions=openInCode;
X-KDE-StartupNotify=false
X-KDE-Priority=TopLevel

[Desktop Action openInCode]
Name=Open in VS Code
Icon=code
Exec=code %F
EOF

  if command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 >/dev/null 2>&1 || true
  fi

  info "Adding 'Open in VS Code' script for Nautilus (GNOME Files)..."

  NAUTILUS_SCRIPTS="$HOME/.local/share/nautilus/scripts"
  mkdir -p "$NAUTILUS_SCRIPTS"

  cat > "$NAUTILUS_SCRIPTS/Open in VS Code" << 'EOF'
#!/usr/bin/env bash
# Nautilus script: Open selection in VS Code
code "$@"
EOF

  chmod +x "$NAUTILUS_SCRIPTS/Open in VS Code"

  if pgrep -x nautilus >/dev/null 2>&1; then
    nautilus -q || true
  fi

  info "VS Code context menu entries added for Dolphin and Nautilus."
}

install_vscode() {
  if is_installed_vscode; then
    info "VS Code is already installed. Only updating context menu."
    configure_vscode_context_menu
    return
  fi

  info "Installing VS Code..."

  # Add Microsoft repo
  if [ ! -f /etc/apt/trusted.gpg.d/microsoft.gpg ]; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | \
      sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null
  fi

  if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" | \
      sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  fi

  sudo apt update
  sudo apt install -y code

  info "VS Code installed. Configuring context menu..."
  configure_vscode_context_menu
}

install_dolphin() {
  if is_installed_dolphin; then
    info "Dolphin is already installed. Skipping."
    return
  fi

  info "Installing Dolphin File Manager..."

  sudo apt update
  sudo apt install -y dolphin

  info "Dolphin installed."
}

install_nvidia_gpu() {
  if is_installed_nvidia; then
    info "NVIDIA drivers already installed (nvidia-smi found). Skipping."
    return
  fi

  if ! lspci | grep -i nvidia >/dev/null 2>&1; then
    warn "No NVIDIA GPU detected via 'lspci'. Skipping NVIDIA driver installation."
    return
  fi

  info "Installing NVIDIA drivers using 'ubuntu-drivers autoinstall'..."

  sudo apt update
  sudo apt install -y ubuntu-drivers-common
  sudo ubuntu-drivers autoinstall

  info "NVIDIA drivers installation finished. A system reboot is usually required for changes to take effect."
}

# ---------- Main menu ----------

main() {
  info "Detecting current installation status..."

  OHMYZ="no";      is_installed_ohmyzsh          && OHMYZ="yes"
  VENVW="no";      is_installed_virtualenvwrapper && VENVW="yes"
  CHROME="no";     is_installed_chrome           && CHROME="yes"
  CONDA="no";      is_installed_conda            && CONDA="yes"
  VSCODE="no";     is_installed_vscode           && VSCODE="yes"
  DOLPHIN="no";    is_installed_dolphin          && DOLPHIN="yes"
  NVIDIA="no";     is_installed_nvidia           && NVIDIA="yes"

  echo
  echo "Which tools would you like to install/configure?"
  echo
  echo " 1) $(status_label "$OHMYZ") Oh My Zsh"
  echo " 2) $(status_label "$VENVW") virtualenvwrapper"
  echo " 3) $(status_label "$CHROME") Google Chrome"
  echo " 4) $(status_label "$CONDA") Conda (Miniconda)"
  echo " 5) $(status_label "$VSCODE") VS Code + context menu (Dolphin & GNOME Files)"
  echo " 6) $(status_label "$DOLPHIN") Dolphin File Manager"
  echo " 7) $(status_label "$NVIDIA") NVIDIA GPU drivers (nvidia-smi)"
  echo
  echo "Examples: 1 3 5   or   1,3,5   or   all"
  read -rp "Enter your choices: " CHOICES_RAW

  if [ -z "$CHOICES_RAW" ]; then
    warn "No selection made. Exiting."
    exit 0
  fi

  CHOICES_RAW="${CHOICES_RAW//,/ }"

  if [[ "$CHOICES_RAW" == "all" ]]; then
    CHOICES=(1 2 3 4 5 6 7)
  else
    read -r -a CHOICES <<< "$CHOICES_RAW"
  fi

  for choice in "${CHOICES[@]}"; do
    case "$choice" in
      1)
        install_ohmyzsh
        ;;
      2)
        install_virtualenvwrapper
        ;;
      3)
        install_chrome
        ;;
      4)
        install_conda
        ;;
      5)
        install_vscode
        ;;
      6)
        install_dolphin
        ;;
      7)
        install_nvidia_gpu
        ;;
      *)
        warn "Invalid choice: $choice"
        ;;
    esac
  done

  info "All selected operations completed. For shell/environment changes or NVIDIA drivers, a new terminal and/or a reboot may be needed."
}

main "$@"

