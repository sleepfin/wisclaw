#!/usr/bin/env bash
#
# Build wizclaw binary for macOS / Linux using PyInstaller.
#
# Usage:
#   ./scripts/build-wizclaw.sh
#
# Requires Python 3.12+.

set -euo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="${REPO_ROOT}/bridge"
VENV_DIR="${REPO_ROOT}/.venv-build"
SPEC_FILE="${BRIDGE_DIR}/wizclaw.spec"

# ── Detect platform and architecture ─────────────────────────────────────

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    darwin) OS="macos" ;;
    linux)  OS="linux" ;;
    *)      OS="$OS" ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH="x64"   ;;
    aarch64) ARCH="arm64"  ;;
    arm64)   ARCH="arm64"  ;;
    *)       ARCH="$ARCH"  ;;
esac

# ── Helpers ───────────────────────────────────────────────────────────────

info()  { printf "\033[0;36m>>> %s\033[0m\n" "$*"; }
ok()    { printf "\033[0;32m%s\033[0m\n" "$*"; }
err()   { printf "\033[0;31mERROR: %s\033[0m\n" "$*" >&2; }

check_command() {
    local name="$1"
    local help_url="${2:-}"
    if ! command -v "$name" &>/dev/null; then
        err "'$name' not found in PATH."
        [ -n "$help_url" ] && echo "  Install it from: $help_url"
        exit 1
    fi
}

# ── Preflight checks ─────────────────────────────────────────────────────

echo ""
info "=== wizclaw ${OS} builder ==="
echo ""

check_command python3 "https://www.python.org/downloads/"
check_command pip3 "https://pip.pypa.io/en/stable/installation/"

PY_VERSION="$(python3 --version 2>&1)"
echo "Python:       ${PY_VERSION}"
echo "Platform:     ${OS}-${ARCH}"
echo "Repo root:    ${REPO_ROOT}"

# ── Virtual environment ──────────────────────────────────────────────────

info "Creating virtual environment at ${VENV_DIR}"

if [ -d "$VENV_DIR" ]; then
    echo "Reusing existing venv."
else
    python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

# ── Install dependencies ─────────────────────────────────────────────────

info "Installing dependencies"

REQUIREMENTS_FILE="${BRIDGE_DIR}/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
    pip install --quiet -r "$REQUIREMENTS_FILE"
fi

pip install --quiet pyinstaller certifi

# ── Build ────────────────────────────────────────────────────────────────

info "Running PyInstaller"

if [ ! -f "$SPEC_FILE" ]; then
    err "Spec file not found at ${SPEC_FILE}"
    echo "Ensure bridge/wizclaw.spec exists in the repo root."
    exit 1
fi

cd "$REPO_ROOT"
pyinstaller --clean --noconfirm "$SPEC_FILE"

# ── Rename output with platform/architecture tag ─────────────────────────

RAW_BIN="${REPO_ROOT}/dist/wizclaw"
TAGGED_NAME="wizclaw-${OS}-${ARCH}"
TAGGED_BIN="${REPO_ROOT}/dist/${TAGGED_NAME}"

if [ -f "$RAW_BIN" ]; then
    cp "$RAW_BIN" "$TAGGED_BIN"
    chmod +x "$TAGGED_BIN"
    SIZE="$(du -h "$TAGGED_BIN" | cut -f1)"

    echo ""
    ok "Build successful!"
    echo "  Output: ${TAGGED_BIN}"
    echo "  Size:   ${SIZE}"
    echo ""
    echo "Quick verification:"
    echo "  ./dist/${TAGGED_NAME} version"
    echo ""
else
    echo ""
    err "Expected output not found at ${RAW_BIN}"
    echo "Check the PyInstaller output above for errors."
    exit 1
fi
