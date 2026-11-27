#!/usr/bin/env bash
set -eE -o pipefail

REPO_NAME="dk-legal-mcp"
COUNTRY_NAME="Denmark"
ZIP_URL="https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip"

on_error() {
    local exit_code=$?
    echo ""
    echo "============================================================================"
    echo "  JurisAtlas Setup Encountered an Error (Exit Code: $exit_code)"
    echo "============================================================================"
    echo "  Please verify your internet connection and try again."
    echo "  Help & alternative downloads: https://jurisatlas.github.io"
    echo ""
    read -r -p "Press Enter to close this window..." _ < /dev/tty || read -r -p "Press Enter to close this window..." _ || true
    exit "$exit_code"
}
trap on_error ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/gui_installer_mac.py" ] || [ ! -f "$SCRIPT_DIR/mcp_server_main.py" ]; then
    echo ""
    echo "============================================================================"
    echo "  JurisAtlas Self-Bootstrapping Setup ($COUNTRY_NAME)"
    echo "============================================================================"
    echo "  Downloading latest $REPO_NAME files from GitHub in the background..."
    echo ""
    BOOT_ROOT="$HOME/.jurisatlas/_bootstrap/$REPO_NAME"
    BOOT_ZIP="$BOOT_ROOT/repo.zip"
    BOOT_EXTRACT="$BOOT_ROOT/extracted"
    rm -rf "$BOOT_EXTRACT"
    mkdir -p "$BOOT_EXTRACT"
    curl -fsSL "$ZIP_URL" -o "$BOOT_ZIP"
    unzip -qo "$BOOT_ZIP" -d "$BOOT_EXTRACT"
    rm -f "$BOOT_ZIP"
    WORK_DIR=""
    for candidate in "$BOOT_EXTRACT"/gui_installer_mac.py "$BOOT_EXTRACT"/*/gui_installer_mac.py; do
        if [ -f "$candidate" ]; then
            WORK_DIR="$(dirname "$candidate")"
            break
        fi
    done
    if [ -z "$WORK_DIR" ]; then
        echo "Error: Downloaded archive did not contain gui_installer_mac.py."
        exit 1
    fi
fi

cd "$WORK_DIR"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
echo "Preparing JurisAtlas Setup Window for $COUNTRY_NAME..."

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv package runner..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

# Prefer uv-managed standalone Python 3.12 (includes bundled Tcl/Tk; avoids Homebrew Python missing _tkinter)
PY_BIN="$(uv python find --managed-python 3.12 2>/dev/null || true)"
if [ -z "$PY_BIN" ]; then
    echo "Preparing standalone Python 3.12 runtime (includes GUI support)..."
    uv python install 3.12
    PY_BIN="$(uv python find --managed-python 3.12)"
fi

"$PY_BIN" "$WORK_DIR/gui_installer_mac.py" "$@"
