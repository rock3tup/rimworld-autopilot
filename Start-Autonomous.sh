#!/usr/bin/env bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

PYTHON_BIN="python3"
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment in $VENV_DIR..."
    $PYTHON_BIN -m venv "$VENV_DIR"
    $VENV_PYTHON -m pip install --upgrade pip
    $VENV_PYTHON -m pip install -r requirements.txt
    echo "Downloading Laya model..."
    $VENV_PYTHON rimworld_laya.py download-model
fi

DEVICE="mps"
if [[ "$(uname -m)" != "arm64" ]]; then
    DEVICE="cpu"
fi

echo "Starting RimWorld Autopilot (Autonomous Mode) on $DEVICE..."
export RIMWORLD_AUTOPILOT_PREFERENCES="${HOME}/Library/Application Support/RimWorld Autopilot/autopilot-preferences.json"
mkdir -p "${HOME}/Library/Application Support/RimWorld Autopilot"

$VENV_PYTHON colony_director.py --device "$DEVICE" "$@"
