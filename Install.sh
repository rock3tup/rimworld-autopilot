#!/usr/bin/env bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Installing RimWorld Autopilot dependencies and setting up environment..."

PYTHON_BIN=""
for candidate in python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
        PYTHON_BIN="$candidate"
        break
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    echo "Error: Python 3 is required. Please install Python 3.10-3.12."
    exit 1
fi

VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in $VENV_DIR..."
    $PYTHON_BIN -m venv "$VENV_DIR"
fi

echo "Installing required Python packages..."
$VENV_PYTHON -m pip install --upgrade pip
$VENV_PYTHON -m pip install -r requirements.txt

echo "Downloading local Laya model files..."
$VENV_PYTHON rimworld_laya.py download-model

# Copy RIMAPI mod to RimWorld Mods folder if found
MAC_MODS="${HOME}/Library/Application Support/Steam/steamapps/common/RimWorld/RimWorld.app/Contents/Resources/Mods"
MAC_APP_SUPPORT_MODS="${HOME}/Library/Application Support/RimWorld/Mods"

DEST_MODS=""
if [ -d "$MAC_APP_SUPPORT_MODS" ] || [ -d "${HOME}/Library/Application Support/RimWorld" ]; then
    mkdir -p "$MAC_APP_SUPPORT_MODS"
    DEST_MODS="$MAC_APP_SUPPORT_MODS"
elif [ -d "$MAC_MODS" ]; then
    DEST_MODS="$MAC_MODS"
fi

if [ -n "$DEST_MODS" ] && [ -d "vendor/RIMAPI" ]; then
    echo "Installing RIMAPI mod to $DEST_MODS/RIMAPI..."
    rm -rf "$DEST_MODS/RIMAPI"
    cp -R "vendor/RIMAPI" "$DEST_MODS/RIMAPI"
    echo "RIMAPI mod installed successfully."
else
    echo "Notice: Could not automatically detect RimWorld Mods folder."
    echo "Please copy vendor/RIMAPI to your RimWorld Mods folder manually."
fi

chmod +x Start-Autonomous.sh Start-Preview.sh Build-Mac.sh 2>/dev/null || true

echo "Installation complete! Run ./Start-Autonomous.sh or python3 autopilot_control.py to start."
