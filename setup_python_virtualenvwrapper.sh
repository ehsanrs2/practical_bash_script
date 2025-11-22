#!/usr/bin/env bash
#
# Ubuntu Python & virtualenvwrapper setup
#
# - Ensures python3, pip, dev tools are installed
# - Makes "python" point to "python3"
# - Installs virtualenv & virtualenvwrapper via pip
# - Configures ~/.bashrc and ~/.zshrc for virtualenvwrapper
#
# Usage:
#   chmod +x setup_python_virtualenvwrapper.sh
#   ./setup_python_virtualenvwrapper.sh
#

set -e

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Command '$1' not found but is required."
    exit 1
  fi
}

### --- 1. نصب پکیج‌های پایه Python --- ###

info "Updating apt and installing Python3 + tools ..."

sudo apt update

sudo apt install -y \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential \
  software-properties-common

### --- 2. تنظیم python -> python3 --- ###

info "Ensuring 'python' runs python3 ..."

if command -v python >/dev/null 2>&1; then
  PY_VER=$(python - << 'PY'
import sys
print(sys.version_info.major)
PY
  )
  if [ "$PY_VER" != "3" ]; then
    warn "'python' is not Python 3 (detected major version: $PY_VER). Trying to install python-is-python3..."
    sudo apt install -y python-is-python3 || warn "Could not install python-is-python3; you may need to fix 'python' manually."
  else
    info "'python' already points to Python 3."
  fi
else
  # روی بعضی سیستم‌ها بسته python-is-python3 این کار را انجام می‌دهد
  if sudo apt install -y python-is-python3; then
    info "Installed python-is-python3; now 'python' should be python3."
  else
    warn "Could not install python-is-python3. Creating a symlink /usr/local/bin/python -> python3 ..."
    PY3_PATH=$(command -v python3)
    if [ -n "$PY3_PATH" ]; then
      sudo ln -sf "$PY3_PATH" /usr/local/bin/python
      info "Created symlink: /usr/local/bin/python -> $PY3_PATH"
    else
      error "python3 not found in PATH, cannot create symlink."
    fi
  fi
fi

require_cmd python3
require_cmd pip3

### --- 3. نصب virtualenv و virtualenvwrapper --- ###

info "Installing virtualenv and virtualenvwrapper via pip3 (system-wide) ..."

# نصب سراسری (اگر ترجیح می‌دهی --user باشد می‌توانیم نسخه دیگر بنویسیم)
sudo pip3 install --upgrade pip
sudo pip3 install --upgrade virtualenv virtualenvwrapper

# پیدا کردن مسیر virtualenv و virtualenvwrapper.sh
VIRTUALENV_BIN=$(command -v virtualenv || true)
VIRTUALENVWRAPPER_SH=$(command -v virtualenvwrapper.sh || true)

if [ -z "$VIRTUALENV_BIN" ]; then
  error "virtualenv command not found after installation."
fi

if [ -z "$VIRTUALENVWRAPPER_SH" ]; then
  # مسیر پیش‌فرض pip روی برخی سیستم‌ها
  if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
    VIRTUALENVWRAPPER_SH="/usr/local/bin/virtualenvwrapper.sh"
  elif [ -f /usr/bin/virtualenvwrapper.sh ]; then
    VIRTUALENVWRAPPER_SH="/usr/bin/virtualenvwrapper.sh"
  else
    error "virtualenvwrapper.sh not found. Check pip installation paths."
  fi
fi

info "virtualenv:        $VIRTUALENV_BIN"
info "virtualenvwrapper: $VIRTUALENVWRAPPER_SH"

### --- 4. تنظیم متغیرها و اضافه‌کردن به .bashrc و .zshrc --- ###

WORKON_HOME="$HOME/.virtualenvs"
PYTHON3_PATH=$(command -v python3)

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
    info "virtualenvwrapper block already present in $file, skipping."
  else
    info "Adding virtualenvwrapper config block to $file"
    printf "\n%s\n" "$VENV_BLOCK" >> "$file"
  fi
}

info "Configuring shell startup files ..."

add_block_if_missing "$HOME/.bashrc"
add_block_if_missing "$HOME/.zshrc"

### --- 5. خلاصه و راهنما --- ###

cat <<EOF

============================================================
✅ Python & virtualenvwrapper setup completed.

Settings:
  WORKON_HOME                = $WORKON_HOME
  VIRTUALENVWRAPPER_PYTHON   = $PYTHON3_PATH
  VIRTUALENVWRAPPER_VIRTUALENV = $VIRTUALENV_BIN
  virtualenvwrapper.sh       = $VIRTUALENVWRAPPER_SH

To start using virtualenvwrapper:

- Open a NEW terminal (or run:  source ~/.bashrc  یا  source ~/.zshrc )
- Create a new env:
    mkvirtualenv myenv
- Work on an env:
    workon myenv
- List envs:
    workon
- Remove env:
    rmvirtualenv myenv

From now on, 'python' and 'python3' both point to Python 3 (if possible).
============================================================
EOF

info "Done."

### --- 6. Pre-initialize virtualenvwrapper to avoid first-run noise in zsh --- ###

info "Pre-initializing virtualenvwrapper to avoid first-run messages in zsh..."

env \
  WORKON_HOME="$WORKON_HOME" \
  VIRTUALENVWRAPPER_PYTHON="$PYTHON3_PATH" \
  VIRTUALENVWRAPPER_VIRTUALENV="$VIRTUALENV_BIN" \
  bash -lc "source \"$VIRTUALENVWRAPPER_SH\" >/dev/null 2>&1" || \
  warn "Could not pre-initialize virtualenvwrapper, but it will still work."


