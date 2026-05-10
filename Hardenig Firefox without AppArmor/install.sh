#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# install.sh — Firefox Hardening Installer (No AppArmor)
# Run INSIDE the Alpine VM as root after Firefox is installed.
#
# Installs all 11 Firefox hardening features:
#
#   Via policies.json:
#     Feature  6 — Disable about:config
#     Feature  7 — Disable Developer Tools
#     Feature  8 — Lock extension installation (only kiosk-guard allowed)
#     Feature  9 — Disable Firefox Sync / Accounts
#     Feature 10 — Disable about:profiles, about:addons, about:settings
#
#   Via autoconfig.js + firefox.cfg:
#     Feature  2 — Download toggle (on/off via one commented line)
#     Feature  5 — Privacy hardening (WebRTC, telemetry, fingerprinting, etc.)
#
#   Via kiosk-guard extension (background.js + content.js):
#     Feature  1 — URL capture per tab (every address bar URL logged)
#     Feature  3 — Download size limit (blocks files above X GB)
#     Feature  4 — Disable all keyboard shortcuts
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────────────────
# PATHS — change if your Firefox is installed elsewhere
# ─────────────────────────────────────────────────────────────────────────
FIREFOX_BIN="/usr/bin/firefox"
FIREFOX_LIB="/usr/lib/firefox"
POLICY_DIR="$FIREFOX_LIB/distribution"
PREF_DIR="$FIREFOX_LIB/defaults/pref"
EXTENSION_DEST="/opt/kiosk-guard"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─────────────────────────────────────────────────────────────────────────
# PRE-FLIGHT CHECKS
# ─────────────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════"
echo " Firefox Hardening Installer"
echo "══════════════════════════════════════════════"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "✖  Must be run as root.  Try:  sudo ./install.sh"
  exit 1
fi

if [ ! -f "$FIREFOX_BIN" ]; then
  echo "✖  Firefox not found at $FIREFOX_BIN"
  echo "   Install it first:  apk add firefox"
  exit 1
fi

if ! command -v zip &>/dev/null; then
  echo "   zip not found — installing..."
  apk add --no-cache zip
fi

echo "✔  Firefox found: $FIREFOX_BIN"
echo "✔  Installing from: $SCRIPT_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────
# STEP 1 — policies.json  (Features 6, 7, 8, 9, 10)
# ─────────────────────────────────────────────────────────────────────────
echo "[1/4] Installing policies.json  (features 6, 7, 8, 9, 10)..."
mkdir -p "$POLICY_DIR"
cp "$SCRIPT_DIR/config/policies.json" "$POLICY_DIR/policies.json"
chmod 644 "$POLICY_DIR/policies.json"
echo "      → $POLICY_DIR/policies.json"

# ─────────────────────────────────────────────────────────────────────────
# STEP 2 — autoconfig.js + firefox.cfg  (Features 2 and 5)
# ─────────────────────────────────────────────────────────────────────────
echo "[2/4] Installing autoconfig.js + firefox.cfg  (features 2, 5)..."
mkdir -p "$PREF_DIR"
cp "$SCRIPT_DIR/config/autoconfig.js" "$PREF_DIR/autoconfig.js"
chmod 644 "$PREF_DIR/autoconfig.js"
echo "      → $PREF_DIR/autoconfig.js"

cp "$SCRIPT_DIR/config/firefox.cfg" "$FIREFOX_LIB/firefox.cfg"
chmod 644 "$FIREFOX_LIB/firefox.cfg"
echo "      → $FIREFOX_LIB/firefox.cfg"

# ─────────────────────────────────────────────────────────────────────────
# STEP 3 — Package + install kiosk-guard extension  (Features 1, 3, 4)
# ─────────────────────────────────────────────────────────────────────────
echo "[3/4] Packaging kiosk-guard extension  (features 1, 3, 4)..."
mkdir -p "$EXTENSION_DEST"
cd "$SCRIPT_DIR/extension"
zip -r "$EXTENSION_DEST/kiosk-guard.xpi" \
    manifest.json \
    background.js \
    content.js
chmod 644 "$EXTENSION_DEST/kiosk-guard.xpi"
cd "$SCRIPT_DIR"
echo "      → $EXTENSION_DEST/kiosk-guard.xpi"

# ─────────────────────────────────────────────────────────────────────────
# STEP 4 — Ensure download folder exists for the browser user
# ─────────────────────────────────────────────────────────────────────────
echo "[4/4] Creating Downloads folder for browser user..."
mkdir -p /home/browser/Downloads
chown browser:browser /home/browser/Downloads 2>/dev/null || true
chmod 750 /home/browser/Downloads
echo "      → /home/browser/Downloads"

# ─────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════"
echo " All 11 features installed successfully."
echo "══════════════════════════════════════════════"
echo ""
echo " Quick reference:"
echo ""
echo " ┌─────────────────────────────────────────────────────────────────┐"
echo " │  Toggle downloads ON/OFF                                        │"
echo " │  File: $FIREFOX_LIB/firefox.cfg                                 │"
echo " │  Line: lockPref(\"browser.download.forbid_open_with\", true);    │"
echo " │  → Add // at start to ENABLE | Remove // to DISABLE             │"
echo " ├─────────────────────────────────────────────────────────────────┤"
echo " │  Change download size limit                                      │"
echo " │  File: $SCRIPT_DIR/extension/background.js                      │"
echo " │  Line: const MAX_DOWNLOAD_SIZE_GB = 5;                          │"
echo " │  → Change the number, then re-run this installer                 │"
echo " ├─────────────────────────────────────────────────────────────────┤"
echo " │  Allow a specific keyboard shortcut back                         │"
echo " │  File: $SCRIPT_DIR/extension/content.js                         │"
echo " │  Line: const ALLOWED_CTRL_KEYS = [\"a\",\"c\",\"v\",\"x\"];           │"
echo " │  → Add the letter to allow that Ctrl+key through                 │"
echo " └─────────────────────────────────────────────────────────────────┘"
echo ""
echo " Reboot the VM to apply all changes."
echo ""
