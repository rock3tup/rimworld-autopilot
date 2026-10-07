#!/usr/bin/env bash
set -e

# Build script for RimWorld Autopilot on macOS

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

VERSION=$(cat VERSION | tr -d '\r\n')
echo "Building RimWorld Autopilot version ${VERSION} for macOS..."

BUILD_VENV=".build-venv"
PYTHON_BIN="python3"

if [ ! -d "$BUILD_VENV" ]; then
    echo "Creating build virtual environment..."
    $PYTHON_BIN -m venv "$BUILD_VENV"
fi

BUILD_PYTHON="$BUILD_VENV/bin/python"
$BUILD_PYTHON -m pip install --upgrade pip
$BUILD_PYTHON -m pip install -r requirements-build.txt

DIST_DIR="dist"
ASSET_ROOT="assets/gui"
ICON_PNG="$ASSET_ROOT/autopilot-emblem.png"
ICON_ICNS="$ASSET_ROOT/autopilot.icns"

# Convert PNG to ICNS if iconutil or sips is available
if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
    echo "Creating macOS .icns icon..."
    ICONSET_DIR="/tmp/autopilot.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1
    iconutil -c icns "$ICONSET_DIR" -o "$ICON_ICNS"
    rm -rf "$ICONSET_DIR"
fi

PYINSTALLER_ARGS=(
    "--noconfirm" "--clean" "--onedir" "--windowed"
    "--distpath" "$DIST_DIR"
    "--add-data" "$ASSET_ROOT:assets/gui"
    "--add-data" "VERSION:."
    "--add-data" "requirements.txt:."
    "--add-data" "LICENSE:."
    "--add-data" "THIRD_PARTY_NOTICES.md:."
    "--add-data" "vendor/RIMAPI:vendor/RIMAPI"
    "--add-data" "*.py:."
    "--name" "RimWorld-Autopilot"
)

if [ -f "$ICON_ICNS" ]; then
    PYINSTALLER_ARGS+=("--icon" "$ICON_ICNS")
fi

echo "Building RimWorld Autopilot app bundle..."
$BUILD_PYTHON -m PyInstaller "${PYINSTALLER_ARGS[@]}" autopilot_control.py

echo "Building RimWorld Autopilot Setup app bundle..."
SETUP_ARGS=(
    "--noconfirm" "--clean" "--onedir" "--windowed"
    "--distpath" "$DIST_DIR"
    "--add-data" "$ASSET_ROOT:assets/gui"
    "--add-data" "VERSION:."
    "--add-data" "requirements.txt:."
    "--add-data" "LICENSE:."
    "--add-data" "THIRD_PARTY_NOTICES.md:."
    "--add-data" "vendor/RIMAPI:vendor/RIMAPI"
    "--add-data" "*.py:."
    "--name" "RimWorld-Autopilot-Setup"
)
if [ -f "$ICON_ICNS" ]; then
    SETUP_ARGS+=("--icon" "$ICON_ICNS")
fi
$BUILD_PYTHON -m PyInstaller "${SETUP_ARGS[@]}" autopilot_setup.py

RELEASE_NAME="RimWorld-Autopilot-macOS-$VERSION"
RELEASE_DIR="$DIST_DIR/$RELEASE_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "Assembling distribution directory..."
$BUILD_PYTHON install_payload.py "$SCRIPT_DIR" "$RELEASE_DIR/Payload"

if [ -d "$DIST_DIR/RimWorld-Autopilot.app" ]; then
    cp -R "$DIST_DIR/RimWorld-Autopilot.app" "$RELEASE_DIR/"
fi
if [ -d "$DIST_DIR/RimWorld-Autopilot-Setup.app" ]; then
    cp -R "$DIST_DIR/RimWorld-Autopilot-Setup.app" "$RELEASE_DIR/"
fi

cp Start-Autonomous.sh "$RELEASE_DIR/" 2>/dev/null || true
cp Start-Preview.sh "$RELEASE_DIR/" 2>/dev/null || true
cp Install.sh "$RELEASE_DIR/" 2>/dev/null || true
chmod +x "$RELEASE_DIR"/*.sh 2>/dev/null || true

echo "Packaging ZIP release..."
cd "$DIST_DIR"
zip -r -q "${RELEASE_NAME}.zip" "$RELEASE_NAME"
cd "$SCRIPT_DIR"

echo "Build complete! Output files are located in $DIST_DIR/"
