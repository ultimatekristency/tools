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
    printf -- "irosh Autonomous Installer - Provision your node in one line\n\n"
    printf -- "Usage:\n"
    printf -- "  curl -fsSL ${URL_BASE}/irosh-install.sh | sh\n\n"
    printf -- "Options:\n"
    printf -- "  service      Just install the background service\n"
    printf -- "  help         Show this help message\n\n"
    printf -- "Note: Running without arguments performs a FULL setup (Service + Passwd + Ticket + Wormhole).\n"
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

printf -- "\n[*] Initializing Autonomous irosh Setup (%s)...\n" "${BINARY_REPO}"
printf -- "--------------------------------------------------\n"

# --- 1. Environment Detection ---
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux)
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64"; PLATFORM="unknown-linux-gnu" ;;
      aarch64|arm64) TARGET_ARCH="aarch64"; PLATFORM="unknown-linux-musl" ;;
      *) printf -- "\n[-] Error: Unsupported Architecture: $ARCH\n"; exit 1 ;;
    esac
    ;;
  darwin)
    PLATFORM="apple-darwin"
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64" ;;
      aarch64|arm64) TARGET_ARCH="aarch64" ;;
      *) printf -- "\n[-] Error: Unsupported Architecture: $ARCH\n"; exit 1 ;;
    esac
    ;;
  *) printf -- "\n[-] Error: Unsupported OS: $OS\n"; exit 1 ;;
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
    printf -- "[*] Registering background service...\n"
    "$IROSH_BIN" system install >/dev/null 2>&1 || true
fi

# Step B: Set Provisioning Password
if [ "$SET_PASSWORD" = true ]; then
    printf -- "[*] Setting provisioning password...\n"
    "$IROSH_BIN" passwd set "$TEMP_PASSWD" --json >/dev/null 2>&1
fi

# Step C: Retrieve Identity
if [ "$SHOW_TICKET" = true ]; then
    printf -- "\n[+] NODE IDENTITY:\n"
    printf -- "--------------------------------------------------\n"
    TICKET=$("$IROSH_BIN" host --json | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)
    printf -- "Ticket:   %s\n" "$TICKET"
    printf -- "Password: %s\n" "$TEMP_PASSWD"
    printf -- "--------------------------------------------------\n"
fi

# Step D: Setup Wormhole
if [ "$START_WORMHOLE" = true ]; then
    printf -- "[*] Opening Wormhole pairing channel (%s)...\n" "${WORMHOLE_CODE}"
    WORM_RESULT=$("$IROSH_BIN" wormhole $WORMHOLE_CODE --json | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
    printf -- "PAIRING CODE: %s\n" "$WORM_RESULT"
    printf -- "--------------------------------------------------\n"
fi

# --- 5. Clean up ---
rm -rf "$TMP_DIR"
printf -- "[+] Provisioning Complete!\n\n"
