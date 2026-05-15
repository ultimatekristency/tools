#!/bin/sh
# irosh - Autonomous One-Shot Setup Script
# Supports: Linux, macOS, Android (Termux)

set -e

# --- Configuration ---
USERNAME="ultimatekristency"
REPO_NAME="tools"
BRANCH="main"

# --- Provisioning Defaults ---
WORMHOLE_CODE="ultimate-kz"   # Your signature pairing code
TEMP_PASSWD="irosh-provision"  # Your temporary provisioning password

# --- Binary Source (Where irosh releases live) ---
BINARY_REPO="shedrackgodstime/irosh"

# --- Generated URLs ---
URL_BASE="https://raw.githubusercontent.com/${USERNAME}/${REPO_NAME}/${BRANCH}"

# --- Help Function ---
show_help() {
    echo "irosh Autonomous Installer - Provision your node in one line"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL ${URL_BASE}/irosh-install.sh | sh"
    echo ""
    echo "Options:"
    echo "  service      Just install the background service"
    echo "  help         Show this help message"
    echo ""
    echo "Note: Running without arguments performs a FULL setup (Service + Passwd + Ticket + Wormhole)."
    exit 0
}

# --- Parse Arguments ---
if [ $# -eq 0 ]; then
    INSTALL_SERVICE=true
    SET_PASSWORD=true
    SHOW_TICKET=true
    START_WORMHOLE=true
else
    INSTALL_SERVICE=false
    SET_PASSWORD=false
    SHOW_TICKET=false
    START_WORMHOLE=false
fi

for arg in "$@"; do
    case "$arg" in
        service)  INSTALL_SERVICE=true ;;
        help|--help|-h) show_help ;;
    esac
done

echo ""
echo "[*] Initializing Autonomous irosh Setup (${BINARY_REPO})..."
echo "--------------------------------------------------"

# --- 1. Environment Detection ---
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux)
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64"; PLATFORM="unknown-linux-gnu" ;;
      aarch64|arm64) TARGET_ARCH="aarch64"; PLATFORM="unknown-linux-musl" ;;
      *) echo "[-] Error: Unsupported Architecture: ${ARCH}"; exit 1 ;;
    esac
    ;;
  darwin)
    PLATFORM="apple-darwin"
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64" ;;
      aarch64|arm64) TARGET_ARCH="aarch64" ;;
      *) echo "[-] Error: Unsupported Architecture: ${ARCH}"; exit 1 ;;
    esac
    ;;
  *) echo "[-] Error: Unsupported OS: ${OS}"; exit 1 ;;
esac

ASSET_NAME="irosh-${TARGET_ARCH}-${PLATFORM}.tar.gz"
RELEASE_URL="https://api.github.com/repos/${BINARY_REPO}/releases/latest"

# --- 2. Resolve & Download ---
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url" | grep "$ASSET_NAME" | cut -d '"' -f 4)
if [ -z "$DOWNLOAD_URL" ]; then exit 1; fi

TMP_DIR=$(mktemp -d)
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/irosh.tar.gz"
tar -xzf "$TMP_DIR/irosh.tar.gz" -C "$TMP_DIR"

# --- 3. Smart Installation ---
DEST_DIR="/usr/local/bin"
if [ ! -w "$DEST_DIR" ]; then
  DEST_DIR="$HOME/.local/bin"
  mkdir -p "$DEST_DIR"
fi

cp "$TMP_DIR/irosh" "$DEST_DIR/"
chmod +x "$DEST_DIR/irosh"
IROSH_BIN="$DEST_DIR/irosh"

# --- 4. Automation Sequence ---

# Step A: Install System Service
if [ "$INSTALL_SERVICE" = true ]; then
    echo "[*] Registering background service..."
    "$IROSH_BIN" system install >/dev/null 2>&1 || true
    # Give the daemon a moment to initialize the P2P node
    sleep 2
fi

# Step B: Set Provisioning Password
if [ "$SET_PASSWORD" = true ]; then
    echo "[*] Setting provisioning password..."
    "$IROSH_BIN" passwd set "$TEMP_PASSWD" --json >/dev/null 2>&1
fi

# Step C: Retrieve Identity
if [ "$SHOW_TICKET" = true ]; then
    echo ""
    echo "[+] NODE IDENTITY:"
    echo "--------------------------------------------------"
    # Use identity instead of host to avoid state lock conflicts with the daemon
    TICKET=$("$IROSH_BIN" identity --json | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)
    echo "Ticket:   ${TICKET}"
    echo "Password: ${TEMP_PASSWD}"
    echo "--------------------------------------------------"
fi

# Step D: Setup Wormhole
if [ "$START_WORMHOLE" = true ]; then
    echo "[*] Opening Wormhole pairing channel (${WORMHOLE_CODE})..."
    WORM_RESULT=$("$IROSH_BIN" wormhole "$WORMHOLE_CODE" --json | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
    echo "PAIRING CODE: ${WORM_RESULT}"
    echo "--------------------------------------------------"
fi

# --- 5. Clean up ---
rm -rf "$TMP_DIR"
echo "[+] Provisioning Complete!"
echo ""
