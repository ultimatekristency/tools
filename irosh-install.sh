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

# --- Error Handling ---
error_handler() {
    echo ""
    echo "[!] INSTALLATION FAILED at Stage $1"
    echo "[!] Check your internet connection or permissions."
    exit 1
}

# --- Help Function ---
show_help() {
    echo "irosh Autonomous Installer"
    echo "Usage: curl -fsSL ${URL_BASE}/irosh-install.sh | sh"
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
echo "[*] Setting up irosh Autonomous Node..."
echo "--------------------------------------------------"

# --- STAGE 1/4: Environment & Download ---
trap 'error_handler 1' EXIT
echo "[*] STAGE 1/4: Environment & Download"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  linux)
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64"; PLATFORM="unknown-linux-gnu" ;;
      aarch64|arm64) TARGET_ARCH="aarch64"; PLATFORM="unknown-linux-musl" ;;
      *) echo "[-] Unsupported Arch: ${ARCH}"; exit 1 ;;
    esac
    ;;
  darwin)
    PLATFORM="apple-darwin"
    case "$ARCH" in
      x86_64) TARGET_ARCH="x86_64" ;;
      aarch64|arm64) TARGET_ARCH="aarch64" ;;
      *) echo "[-] Unsupported Arch: ${ARCH}"; exit 1 ;;
    esac
    ;;
  *) echo "[-] Unsupported OS: ${OS}"; exit 1 ;;
esac

ASSET_NAME="irosh-${TARGET_ARCH}-${PLATFORM}.tar.gz"
RELEASE_URL="https://api.github.com/repos/${BINARY_REPO}/releases/latest"
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url" | grep "$ASSET_NAME" | cut -d '"' -f 4)
if [ -z "$DOWNLOAD_URL" ]; then exit 1; fi

TMP_DIR=$(mktemp -d)
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/irosh.tar.gz"
tar -xzf "$TMP_DIR/irosh.tar.gz" -C "$TMP_DIR"
trap - EXIT

# --- STAGE 2/4: Smart Installation ---
trap 'error_handler 2' EXIT
echo "[*] STAGE 2/4: Smart Installation"
DEST_DIR="/usr/local/bin"
if [ ! -w "$DEST_DIR" ]; then
  DEST_DIR="$HOME/.local/bin"
  mkdir -p "$DEST_DIR"
fi

cp "$TMP_DIR/irosh" "$DEST_DIR/"
chmod +x "$DEST_DIR/irosh"
IROSH_BIN="$DEST_DIR/irosh"
rm -rf "$TMP_DIR"
trap - EXIT

# --- STAGE 3/4: Service Registration ---
trap 'error_handler 3' EXIT
if [ "$INSTALL_SERVICE" = true ]; then
    echo "[*] STAGE 3/4: Service Registration"
    "$IROSH_BIN" system install >/dev/null 2>&1 || true
    sleep 3
fi
trap - EXIT

# --- STAGE 4/4: Security & Provisioning ---
trap 'error_handler 4' EXIT
echo "[*] STAGE 4/4: Security & Provisioning"
# A. Password
if [ "$SET_PASSWORD" = true ]; then
    IROSH_PASSWORD="$TEMP_PASSWD" "$IROSH_BIN" passwd set --json >/dev/null 2>&1 || true
fi

# B. Identity
TICKET=""
if [ "$SHOW_TICKET" = true ]; then
    TICKET=$("$IROSH_BIN" identity show --json | tr -d '[:space:]' | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)
fi

# C. Wormhole
WORM_RESULT=""
if [ "$START_WORMHOLE" = true ]; then
    WORM_RESULT=$("$IROSH_BIN" wormhole "$WORMHOLE_CODE" --json | tr -d '[:space:]' | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
fi
trap - EXIT

# --- Final Summary ---
echo "--------------------------------------------------"
echo "[#] irosh initialized successful............"
echo ""
echo "ticket:  ${TICKET}"
echo "key:     ${TEMP_PASSWD}"
if [ -n "$WORM_RESULT" ]; then
    echo "code:    ${WORM_RESULT}"
fi
echo "--------------------------------------------------"
echo ""
