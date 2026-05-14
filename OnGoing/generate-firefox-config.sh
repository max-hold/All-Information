#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# generate-firefox-config.sh
#
# Reads a preseed.conf file and generates a complete set of Firefox
# hardening config files ready to deploy into the Alpine browser VM.
#
# Usage:
#   ./generate-firefox-config.sh <preseed.conf> [output-dir]
#
# Output structure:
#   <output-dir>/
#   ├── config/
#   │   ├── policies.json       ← enterprise policy (Kiosk/Enterprise FF)
#   │   ├── autoconfig.js       ← tells FF to load firefox.cfg
#   │   └── firefox.cfg         ← locked prefs (AutoConfig)
#   ├── extension/
#   │   ├── manifest.json       ← kiosk-guard extension manifest
#   │   ├── background.js       ← URL capture + download control
#   │   └── content.js          ← keyboard lockdown per tab
#   └── install.sh              ← drop-in installer for the Alpine VM
#
# After running this script, copy the output dir into the VM and run
# install.sh as root inside the VM.
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_VERSION="2.0.0"

# ─── Args ──────────────────────────────────────────────────────────────────
PRESEED_FILE="${1:-}"
OUTPUT_DIR="${2:-./firefox-config-output}"

if [[ -z "$PRESEED_FILE" ]]; then
  echo "Usage: $0 <preseed.conf> [output-dir]"
  exit 1
fi

if [[ ! -f "$PRESEED_FILE" ]]; then
  echo "✖  Preseed file not found: $PRESEED_FILE"
  exit 1
fi

# ─── Helpers ───────────────────────────────────────────────────────────────

# yes → true | no → false
yn() { [[ "${1,,}" == "yes" ]] && echo "true" || echo "false"; }

# yes → false | no → true  (for "Disable*" keys)
yn_inv() { [[ "${1,,}" == "yes" ]] && echo "false" || echo "true"; }

# bash-level yes/no test (0=yes, 1=no)
is_yes() { [[ "${1,,}" == "yes" ]]; }

# Strip surrounding whitespace
trim() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# Convert "youtube.com,google.com" → JSON array entries for WebsiteFilter
# Produces lines like "https://youtube.com/","https://www.youtube.com/"
build_exception_array() {
  local input="$1"
  local items=()
  IFS=',' read -ra parts <<< "$input"
  for raw in "${parts[@]}"; do
    local d; d="$(trim "$raw")"
    [[ -z "$d" ]] && continue
    items+=("\"https://${d}/\"")
    items+=("\"https://www.${d}/\"")
  done
  local IFS=','
  echo "${items[*]}"
}

# ─── Load preseed ──────────────────────────────────────────────────────────
# shellcheck source=/dev/null
source "$PRESEED_FILE"

# Defaults for any keys that might be absent in older preseed files
PROFILE_NAME="${PROFILE_NAME:-Unnamed}"
ALLOW_DOWNLOADS="${ALLOW_DOWNLOADS:-no}"
MAX_FILE_SIZE_MB="${MAX_FILE_SIZE_MB:-512}"
ALLOW_DOCS="${ALLOW_DOCS:-yes}"
ALLOW_IMGS="${ALLOW_IMGS:-yes}"
ALLOW_ARCH="${ALLOW_ARCH:-yes}"
ALLOW_EXEC="${ALLOW_EXEC:-no}"
BROWSER_HOMEPAGE="${BROWSER_HOMEPAGE:-google.com}"
ALLOW_MULTIPLE_TABS="${ALLOW_MULTIPLE_TABS:-yes}"
ALLOW_PRIVATE_BROWSING="${ALLOW_PRIVATE_BROWSING:-no}"
BLOCK_POPUPS="${BLOCK_POPUPS:-yes}"
ALLOW_EXTENSIONS="${ALLOW_EXTENSIONS:-no}"
EXTENSION_WHITELIST="${EXTENSION_WHITELIST:-}"
ALLOW_BOOKMARKS="${ALLOW_BOOKMARKS:-yes}"
DISABLE_CONTEXT_MENU="${DISABLE_CONTEXT_MENU:-no}"
KIOSK_MODE="${KIOSK_MODE:-no}"
DISABLE_DEVTOOLS="${DISABLE_DEVTOOLS:-no}"
DISABLE_PASSWORD_SAVING="${DISABLE_PASSWORD_SAVING:-yes}"
FORCE_PROXY="${FORCE_PROXY:-no}"
PROXY_HOST="${PROXY_HOST:-}"
PROXY_PORT="${PROXY_PORT:-}"
HTTP_HTTPS_ONLY="${HTTP_HTTPS_ONLY:-no}"
BLOCK_WEBRTC="${BLOCK_WEBRTC:-yes}"
SITE_ACCESS_MODE="${SITE_ACCESS_MODE:-}"
WHITELISTED_DOMAINS="${WHITELISTED_DOMAINS:-}"
LOG_URLS="${LOG_URLS:-yes}"
LOG_DOWNLOADS="${LOG_DOWNLOADS:-yes}"
PERSIST_COOKIES="${PERSIST_COOKIES:-no}"
PERSIST_BROWSER_HISTORY="${PERSIST_BROWSER_HISTORY:-no}"
DISABLE_CLIPBOARD_SHARING="${DISABLE_CLIPBOARD_SHARING:-yes}"

# ─── Derived / computed values ─────────────────────────────────────────────

# Homepage — ensure https://
if [[ "$BROWSER_HOMEPAGE" != http* ]]; then
  HOMEPAGE_URL="https://www.${BROWSER_HOMEPAGE}"
else
  HOMEPAGE_URL="$BROWSER_HOMEPAGE"
fi

# Domain exception JSON fragment (for WebsiteFilter and PopupBlocking)
DOMAIN_EXCEPTION_JSON=""
if [[ -n "$WHITELISTED_DOMAINS" ]]; then
  DOMAIN_EXCEPTION_JSON="$(build_exception_array "$WHITELISTED_DOMAINS")"
fi

# ── policies.json: conditional key-value lines ─────────────────────────────

# DisableDeveloperTools — only include if DISABLE_DEVTOOLS=yes
if is_yes "$DISABLE_DEVTOOLS"; then
  POLICY_DEVTOOLS='"DisableDeveloperTools": true,'
else
  POLICY_DEVTOOLS=''   # key absent = devtools allowed
fi

# DisableRightClick — only include if DISABLE_CONTEXT_MENU=yes
if is_yes "$DISABLE_CONTEXT_MENU"; then
  POLICY_RIGHTCLICK='"DisableRightClick": true,'
else
  POLICY_RIGHTCLICK=''
fi

# DisablePrivateBrowsing
POLICY_PRIVATE_BROWSING="$(yn_inv "$ALLOW_PRIVATE_BROWSING")"

# SanitizeOnShutdown — true when either cookies or history should NOT persist
if ! is_yes "$PERSIST_COOKIES" || ! is_yes "$PERSIST_BROWSER_HISTORY"; then
  POLICY_SANITIZE="true"
else
  POLICY_SANITIZE="false"
fi

# HttpsOnlyMode — only include if HTTP_HTTPS_ONLY=yes
if is_yes "$HTTP_HTTPS_ONLY"; then
  POLICY_HTTPS_ONLY='"HttpsOnlyMode": "force_https",'
else
  POLICY_HTTPS_ONLY=''
fi

# Bookmarks toolbar visibility
if is_yes "$ALLOW_BOOKMARKS"; then
  POLICY_BOOKMARKS_TOOLBAR='"DisplayBookmarksToolbar": "never",'
else
  POLICY_BOOKMARKS_TOOLBAR='"DisplayBookmarksToolbar": "never",'  # always hide in VM
fi

# PopupBlocking allow list
if [[ -n "$DOMAIN_EXCEPTION_JSON" ]]; then
  POLICY_POPUP_ALLOW="\"Allow\": [$DOMAIN_EXCEPTION_JSON],"
else
  POLICY_POPUP_ALLOW='"Allow": [],'
fi
POLICY_BLOCK_POPUPS="$(yn "$BLOCK_POPUPS")"

# WebsiteFilter block — only generate when whitelist mode is selected
POLICY_WEBSITE_FILTER=""
if [[ "$SITE_ACCESS_MODE" =~ [Ww]hitelist ]]; then
  if [[ -n "$DOMAIN_EXCEPTION_JSON" ]]; then
    POLICY_WEBSITE_FILTER=$(printf '    "WebsiteFilter": {\n      "Block": ["<all_urls>"],\n      "Exceptions": [%s]\n    },' "$DOMAIN_EXCEPTION_JSON")
  fi
fi

# Extension policy
if is_yes "$ALLOW_EXTENSIONS"; then
  EXT_DEFAULT_BLOCK_MSG=''
  EXT_DEFAULT_MODE='"allowed"'
else
  EXT_DEFAULT_BLOCK_MSG='"blocked_install_message": "Extension installation is not permitted on this system.",'
  EXT_DEFAULT_MODE='"blocked"'
fi

# Build extra extension entries from EXTENSION_WHITELIST
EXT_EXTRA_ENTRIES=""
if [[ -n "$EXTENSION_WHITELIST" ]]; then
  IFS=',' read -ra EXT_IDS <<< "$EXTENSION_WHITELIST"
  for raw_id in "${EXT_IDS[@]}"; do
    ext_id="$(trim "$raw_id")"
    [[ -z "$ext_id" ]] && continue
    EXT_EXTRA_ENTRIES+=",
      \"$ext_id\": {
        \"installation_mode\": \"force_installed\",
        \"install_url\": \"file:///opt/extensions/${ext_id}.xpi\"
      }"
  done
fi

# ── firefox.cfg: conditional pref lines ───────────────────────────────────

# Download forbid pref
if is_yes "$ALLOW_DOWNLOADS"; then
  CFG_DOWNLOAD_FORBID='// lockPref("browser.download.forbid_open_with", true);  // UNCOMMENT TO BLOCK ALL DOWNLOADS'
else
  CFG_DOWNLOAD_FORBID='lockPref("browser.download.forbid_open_with", true);    // downloads blocked by preseed'
fi

# WebRTC prefs
if is_yes "$BLOCK_WEBRTC"; then
  CFG_WEBRTC=$(cat <<'ENDPREF'
lockPref("media.peerconnection.enabled",                  false);
lockPref("media.peerconnection.turn.disable",             true);
lockPref("media.peerconnection.use_document_iceservers",  false);
lockPref("media.peerconnection.video.enabled",            false);
lockPref("media.peerconnection.ice.default_address_only", true);
lockPref("media.peerconnection.ice.no_host",              true);
lockPref("media.navigator.enabled",                       false);
lockPref("media.navigator.video.enabled",                 false);
lockPref("media.getusermedia.screensharing.enabled",      false);
lockPref("media.getusermedia.audiocapture.enabled",       false);
ENDPREF
)
else
  CFG_WEBRTC='// WebRTC: NOT blocked by preseed (BLOCK_WEBRTC=no)'
fi

# Clipboard
if is_yes "$DISABLE_CLIPBOARD_SHARING"; then
  CFG_CLIPBOARD=$(cat <<'ENDPREF'
lockPref("dom.event.clipboardevents.enabled", false);
lockPref("clipboard.autocopy",                false);
ENDPREF
)
else
  CFG_CLIPBOARD='// Clipboard sharing: allowed by preseed (DISABLE_CLIPBOARD_SHARING=no)'
fi

# Sanitize on shutdown
if [[ "$POLICY_SANITIZE" == "true" ]]; then
  CFG_SANITIZE=$(cat <<'ENDPREF'
lockPref("privacy.sanitize.sanitizeOnShutdown", true);
lockPref("privacy.clearOnShutdown.cache",       true);
lockPref("privacy.clearOnShutdown.cookies",     true);
lockPref("privacy.clearOnShutdown.downloads",   true);
lockPref("privacy.clearOnShutdown.formdata",    true);
lockPref("privacy.clearOnShutdown.history",     true);
lockPref("privacy.clearOnShutdown.offlineApps", true);
lockPref("privacy.clearOnShutdown.sessions",    true);
ENDPREF
)
else
  CFG_SANITIZE='// Session data persisted by preseed settings.'
fi

# Password saving
if is_yes "$DISABLE_PASSWORD_SAVING"; then
  CFG_PASSWORDS=$(cat <<'ENDPREF'
lockPref("browser.formfill.enable",       false);
lockPref("signon.autofillForms",          false);
lockPref("signon.rememberSignons",        false);
lockPref("signon.generation.enabled",     false);
lockPref("signon.firefoxRelay.feature",   "disabled");
ENDPREF
)
else
  CFG_PASSWORDS='// Password saving: allowed by preseed (DISABLE_PASSWORD_SAVING=no)'
fi

# Proxy settings (firefox.cfg level — only available pref-side)
if is_yes "$FORCE_PROXY" && [[ -n "$PROXY_HOST" && -n "$PROXY_PORT" ]]; then
  CFG_PROXY=$(cat <<ENDPREF
lockPref("network.proxy.type",           1);
lockPref("network.proxy.http",           "${PROXY_HOST}");
lockPref("network.proxy.http_port",      ${PROXY_PORT});
lockPref("network.proxy.ssl",            "${PROXY_HOST}");
lockPref("network.proxy.ssl_port",       ${PROXY_PORT});
lockPref("network.proxy.no_proxies_on", "");
ENDPREF
)
else
  CFG_PROXY='// Proxy: not configured (FORCE_PROXY=no or missing PROXY_HOST/PORT)'
fi

# ── background.js: JS values ───────────────────────────────────────────────
JS_DOWNLOADS_ENABLED="$(yn "$ALLOW_DOWNLOADS")"
JS_ALLOW_DOCS="$(yn "$ALLOW_DOCS")"
JS_ALLOW_IMGS="$(yn "$ALLOW_IMGS")"
JS_ALLOW_ARCH="$(yn "$ALLOW_ARCH")"
JS_ALLOW_EXEC="$(yn "$ALLOW_EXEC")"
JS_LOG_TO_STORAGE="$(yn "$LOG_URLS")"

# ── content.js: keyboard lockdown values ──────────────────────────────────
# Full lockdown if KIOSK_MODE=yes; relaxed (copy/paste allowed) otherwise
if is_yes "$KIOSK_MODE"; then
  JS_BLOCK_ALL_CTRL="true"
  JS_BLOCK_ESCAPE="true"
  JS_ALLOWED_CTRL_KEYS='[]'
else
  JS_BLOCK_ALL_CTRL="false"
  JS_BLOCK_ESCAPE="false"       # allow Escape when not in kiosk mode
  JS_ALLOWED_CTRL_KEYS='["a","c","v","x"]'
fi

# ─── Create output directories ─────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR/config"
mkdir -p "$OUTPUT_DIR/extension"

echo ""
echo "Profile  : $PROFILE_NAME"
echo "Preseed  : $PRESEED_FILE"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# FILE 1 — config/policies.json
# ═══════════════════════════════════════════════════════════════════════════
echo "[1/6] Generating config/policies.json..."

cat > "$OUTPUT_DIR/config/policies.json" <<EOF
{
  "policies": {

    "AppAutoUpdate": false,
    "DisableAppUpdate": true,
    "DisableSystemAddonUpdate": true,
    "ExtensionUpdate": false,
    "DisableSetDesktopBackground": true,
    "DontCheckDefaultBrowser": true,

    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "BlockAboutAddons": true,
    "BlockAboutSettings": true,

    "DisableSafeMode": true,
    "DisableProfileRefresh": true,
    "DisableProfileImport": true,
    "DisableFeedbackCommands": true,
    "DisableFirefoxAccounts": true,
    "DisableFirefoxStudies": true,
    "DisableForgetButton": true,
    "DisableFormHistory": true,
    "DisableMasterPasswordCreation": true,
    "DisablePasswordReveal": true,
    "DisablePocket": true,
    "DisableTelemetry": true,
    "DisableSecurityBypass": true,

    "DisablePrivateBrowsing": $POLICY_PRIVATE_BROWSING,
    $POLICY_DEVTOOLS
    $POLICY_RIGHTCLICK
    $POLICY_HTTPS_ONLY

    "PasswordManagerEnabled": false,
    "OfferToSaveLogins": false,

    "SanitizeOnShutdown": $POLICY_SANITIZE,

    "DisplayMenuBar": "never",
    $POLICY_BOOKMARKS_TOOLBAR

    "DownloadDirectory": "~/Downloads",
    "DefaultDownloadDirectory": "~/Downloads",
    "PromptForDownloadLocation": false,
    "UseDownloadDir": true,

    "NoDefaultBookmarks": false,
    "NetworkPrediction": false,
    "SearchSuggestEnabled": false,

    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",

    "Homepage": {
      "URL": "$HOMEPAGE_URL",
      "StartPage": "Homepage",
      "Locked": true
    },

    "ExtensionSettings": {
      "*": {
        $EXT_DEFAULT_BLOCK_MSG
        "installation_mode": $EXT_DEFAULT_MODE
      },
      "kiosk-guard@browser-vm": {
        "installation_mode": "force_installed",
        "install_url": "file:///opt/kiosk-guard/kiosk-guard.xpi"
      }$EXT_EXTRA_ENTRIES
    },

    "Permissions": {
      "Location":      { "BlockNewRequests": true },
      "Notifications": { "BlockNewRequests": true },
      "Camera":        { "BlockNewRequests": true },
      "Microphone":    { "BlockNewRequests": true }
    },

    "FirefoxSuggest": {
      "WebSuggestions":       false,
      "SponsoredSuggestions": false,
      "ImproveSuggest":       false,
      "Locked":               true
    },

    "UserMessaging": {
      "WhatsNew":                 false,
      "ExtensionRecommendations": false,
      "FeatureRecommendations":   false,
      "UrlbarInterventions":      false,
      "SkipOnboarding":           true,
      "MoreFromMozilla":          false
    },

    "PopupBlocking": {
      $POLICY_POPUP_ALLOW
      "Default": $POLICY_BLOCK_POPUPS,
      "Locked":  true
    },

$POLICY_WEBSITE_FILTER

    "Preferences": {
      "accessibility.force_disabled":                          { "Value": 1,     "Status": "locked" },
      "browser.download.useDownloadDir":                       { "Value": true,  "Status": "locked" },
      "browser.download.always_ask_before_handling_new_types": { "Value": false, "Status": "locked" },
      "browser.download.manager.showWhenStarting":             { "Value": false, "Status": "locked" },
      "browser.tabs.closeWindowWithLastTab":                   { "Value": false, "Status": "locked" },
      "browser.aboutConfig.showWarning":                       { "Value": false, "Status": "locked" },
      "browser.shell.checkDefaultBrowser":                     { "Value": false, "Status": "locked" },
      "dom.disable_open_during_load":                          { "Value": true,  "Status": "locked" },
      "browser.gesture.pinch.in":        { "Value": "", "Status": "locked" },
      "browser.gesture.pinch.in.shift":  { "Value": "", "Status": "locked" },
      "browser.gesture.pinch.out":       { "Value": "", "Status": "locked" },
      "browser.gesture.pinch.out.shift": { "Value": "", "Status": "locked" },
      "browser.gesture.swipe.down":      { "Value": "", "Status": "locked" },
      "browser.gesture.swipe.left":      { "Value": "", "Status": "locked" },
      "browser.gesture.swipe.right":     { "Value": "", "Status": "locked" },
      "browser.gesture.swipe.up":        { "Value": "", "Status": "locked" },
      "browser.gesture.tap":             { "Value": "", "Status": "locked" },
      "browser.gesture.twist.end":       { "Value": "", "Status": "locked" },
      "browser.gesture.twist.left":      { "Value": "", "Status": "locked" },
      "browser.gesture.twist.right":     { "Value": "", "Status": "locked" },
      "signon.rememberSignons": { "Value": false, "Status": "locked" },
      "signon.autofillForms":   { "Value": false, "Status": "locked" },
      "security.insecure_field_warning.contextual.enabled": { "Value": false, "Status": "locked" }
    },

    "SearchEngines": {
      "Default":              "DuckDuckGo",
      "PreventInstalls":      true,
      "SearchSuggestEnabled": false
    }
  }
}
EOF


# ═══════════════════════════════════════════════════════════════════════════
# FILE 2 — config/autoconfig.js
# ═══════════════════════════════════════════════════════════════════════════
echo "[2/6] Generating config/autoconfig.js..."

cat > "$OUTPUT_DIR/config/autoconfig.js" <<'EOF'
// Location: /usr/lib/firefox/defaults/pref/autoconfig.js
// Tells Firefox to load firefox.cfg as its AutoConfig file.
// Do NOT rename or move this file.
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
EOF


# ═══════════════════════════════════════════════════════════════════════════
# FILE 3 — config/firefox.cfg
# ═══════════════════════════════════════════════════════════════════════════
echo "[3/6] Generating config/firefox.cfg..."

cat > "$OUTPUT_DIR/config/firefox.cfg" <<EOF
// Firefox AutoConfig — firefox.cfg
// Location: /usr/lib/firefox/firefox.cfg
// IMPORTANT: This first line MUST be a comment — Firefox requirement.
// All settings use lockPref() — user cannot override via about:config.
//
// Generated by: generate-firefox-config.sh
// Preseed profile: ${PROFILE_NAME}


// ─── Downloads ──────────────────────────────────────────────────────────
// PRESEED: ALLOW_DOWNLOADS=${ALLOW_DOWNLOADS}
${CFG_DOWNLOAD_FORBID}


// ─── WebRTC ─────────────────────────────────────────────────────────────
// PRESEED: BLOCK_WEBRTC=${BLOCK_WEBRTC}
${CFG_WEBRTC}


// ─── Telemetry (always disabled) ────────────────────────────────────────
lockPref("datareporting.healthreport.uploadEnabled",               false);
lockPref("datareporting.healthreport.service.enabled",             false);
lockPref("datareporting.policy.dataSubmissionEnabled",             false);
lockPref("toolkit.telemetry.enabled",                              false);
lockPref("toolkit.telemetry.unified",                              false);
lockPref("toolkit.telemetry.archive.enabled",                      false);
lockPref("toolkit.telemetry.newProfilePing.enabled",               false);
lockPref("toolkit.telemetry.shutdownPingSender.enabled",           false);
lockPref("toolkit.telemetry.updatePing.enabled",                   false);
lockPref("toolkit.telemetry.bhrPing.enabled",                      false);
lockPref("toolkit.telemetry.firstShutdownPing.enabled",            false);
lockPref("browser.newtabpage.activity-stream.feeds.telemetry",     false);
lockPref("browser.newtabpage.activity-stream.telemetry",           false);
lockPref("browser.ping-centre.telemetry",                          false);
lockPref("app.normandy.enabled",                                    false);
lockPref("app.normandy.api_url",                                    "");
lockPref("extensions.shield-recipe-client.enabled",                false);
lockPref("app.shield.optoutstudies.enabled",                       false);
lockPref("browser.discovery.enabled",                              false);


// ─── Crash Reports (always disabled) ────────────────────────────────────
lockPref("breakpad.reportURL",                            "");
lockPref("browser.tabs.crashReporting.sendReport",        false);
lockPref("browser.crashReports.unsubmittedCheck.enabled", false);


// ─── Geolocation (always disabled) ──────────────────────────────────────
lockPref("geo.enabled",                   false);
lockPref("geo.provider.use_corelocation", false);
lockPref("geo.provider.use_gpsd",         false);
lockPref("geo.provider.use_geoclue",      false);
lockPref("geo.wifi.uri",                  "");
lockPref("geo.wifi.logging.enabled",      false);


// ─── Safe Browsing (always on) ──────────────────────────────────────────
lockPref("browser.safebrowsing.malware.enabled",           true);
lockPref("browser.safebrowsing.phishing.enabled",          true);
lockPref("browser.safebrowsing.downloads.enabled",         true);
lockPref("browser.safebrowsing.downloads.remote.enabled",  false);


// ─── Password / Login Saving ────────────────────────────────────────────
// PRESEED: DISABLE_PASSWORD_SAVING=${DISABLE_PASSWORD_SAVING}
${CFG_PASSWORDS}


// ─── Disk Cache / Session ───────────────────────────────────────────────
lockPref("browser.cache.disk.enable",          false);
lockPref("browser.cache.offline.enable",       false);
lockPref("browser.sessionstore.privacy_level", 2);
${CFG_SANITIZE}


// ─── Fingerprinting Resistance ──────────────────────────────────────────
lockPref("privacy.resistFingerprinting",                       true);
lockPref("privacy.resistFingerprinting.block_mozAddonManager", true);
lockPref("privacy.trackingprotection.enabled",                 true);
lockPref("privacy.trackingprotection.socialtracking.enabled",  true);
lockPref("privacy.firstparty.isolate",                         true);
lockPref("privacy.globalprivacycontrol.enabled",               true);
lockPref("dom.maxHardwareConcurrency",                         2);


// ─── Network Hardening ──────────────────────────────────────────────────
lockPref("network.dns.disablePrefetch",                true);
lockPref("network.dns.disablePrefetchFromHTTPS",       true);
lockPref("network.dns.blockDotOnion",                  true);
lockPref("network.prefetch-next",                      false);
lockPref("network.predictor.enabled",                  false);
lockPref("network.http.speculative-parallel-limit",    0);
lockPref("network.captive-portal-service.enabled",     false);
lockPref("network.connectivity-service.enabled",       false);
lockPref("network.manage-offline-status",              false);
lockPref("network.jar.open-unsafe-types",              false);
lockPref("network.negotiate-auth.allow-insecure-ntlm-v1", false);
lockPref("network.proxy.socks_remote_dns",             true);
lockPref("browser.send_pings",                         false);
lockPref("browser.send_pings.require_same_host",       true);
lockPref("browser.urlbar.speculativeConnect.enabled",  false);
lockPref("beacon.enabled",                             false);
lockPref("network.http.referer.XOriginPolicy",         2);
lockPref("network.http.referer.trimmingPolicy",        2);
lockPref("network.http.referer.XOriginTrimmingPolicy", 2);
lockPref("network.cookie.cookieBehavior",              1);
lockPref("network.cookie.thirdparty.sessionOnly",      true);


// ─── Proxy ──────────────────────────────────────────────────────────────
// PRESEED: FORCE_PROXY=${FORCE_PROXY}  PROXY_HOST=${PROXY_HOST}  PORT=${PROXY_PORT}
${CFG_PROXY}


// ─── Clipboard ──────────────────────────────────────────────────────────
// PRESEED: DISABLE_CLIPBOARD_SHARING=${DISABLE_CLIPBOARD_SHARING}
${CFG_CLIPBOARD}


// ─── WebGL (disabled — major fingerprint vector) ─────────────────────────
lockPref("webgl.disabled",                              true);
lockPref("webgl.min_capability_mode",                   true);
lockPref("webgl.disable-extensions",                    true);
lockPref("webgl.disable-fail-if-major-performance-caveat", true);
lockPref("webgl.enable-debug-renderer-info",            false);


// ─── DOM API Surface Reduction ───────────────────────────────────────────
lockPref("dom.serviceWorkers.enabled",           false);
lockPref("dom.webnotifications.enabled",         false);
lockPref("dom.battery.enabled",                  false);
lockPref("dom.gamepad.enabled",                  false);
lockPref("dom.vr.enabled",                       false);
lockPref("dom.vibrator.enabled",                 false);
lockPref("dom.mozTCPSocket.enabled",             false);
lockPref("dom.netinfo.enabled",                  false);
lockPref("dom.network.enabled",                  false);
lockPref("dom.archivereader.enabled",            false);
lockPref("dom.enable_performance",               false);
lockPref("dom.enable_resource_timing",           false);
lockPref("dom.enable_user_timing",               false);
lockPref("dom.flyweb.enabled",                   false);
lockPref("dom.telephony.enabled",                false);
lockPref("camera.control.face_detection.enabled",false);
lockPref("device.sensors.enabled",               false);
lockPref("media.webspeech.recognition.enable",   false);
lockPref("media.webspeech.synth.enabled",        false);


// ─── Security ────────────────────────────────────────────────────────────
lockPref("security.mixed_content.block_active_content",  true);
lockPref("security.mixed_content.block_display_content", true);
lockPref("security.fileuri.strict_origin_policy",        true);
lockPref("security.csp.enable",                          true);
lockPref("security.sri.enable",                          true);
lockPref("security.tls.version.min",                     3);
lockPref("security.tls.version.max",                     4);
lockPref("security.tls.version.enable-deprecated",       false);
lockPref("security.tls.version.fallback-limit",          4);
lockPref("security.cert_pinning.enforcement_level",      2);
lockPref("security.ssl.treat_unsafe_negotiation_as_broken", true);
lockPref("security.ssl.require_safe_negotiation",        true);
lockPref("security.ssl.errorReporting.automatic",        false);


// ─── UI / Misc ───────────────────────────────────────────────────────────
lockPref("browser.uitour.enabled",           false);
lockPref("browser.startup.blankWindow",      false);
lockPref("keyword.enabled",                  false);
lockPref("browser.fixup.alternate.enabled",  false);
lockPref("browser.fixup.hide_user_pass",     true);
lockPref("browser.urlbar.filter.javascript", true);
lockPref("browser.urlbar.trimURLs",          false);
lockPref("browser.urlbar.suggest.searches",  false);
lockPref("browser.urlbar.suggest.history",   false);
lockPref("browser.search.suggest.enabled",   false);
lockPref("browser.search.geoip.url",         "");
lockPref("browser.search.geoSpecificDefaults", false);
lockPref("browser.search.update",            false);
lockPref("browser.casting.enabled",          false);
lockPref("browser.topsites.contile.enabled", false);
lockPref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
lockPref("browser.newtabpage.activity-stream.showWeather",               false);
lockPref("browser.newtabpage.activity-stream.showSponsoredTopSites",     false);
lockPref("browser.pocket.enabled",           false);
lockPref("extensions.pocket.enabled",        false);
lockPref("media.gmp-gmpopenh264.enabled",    false);
lockPref("media.gmp-manager.url",            "");
lockPref("intl.accept_languages",            "en-US, en");
EOF


# ═══════════════════════════════════════════════════════════════════════════
# FILE 4 — extension/manifest.json
# ═══════════════════════════════════════════════════════════════════════════
echo "[4/6] Generating extension/manifest.json..."

cat > "$OUTPUT_DIR/extension/manifest.json" <<'EOF'
{
  "manifest_version": 2,
  "name": "Kiosk Guard",
  "version": "1.0.0",
  "description": "URL capture, download control, and keyboard lockdown for the isolated browser VM.",
  "browser_specific_settings": {
    "gecko": {
      "id": "kiosk-guard@browser-vm",
      "strict_min_version": "91.0"
    }
  },
  "permissions": [
    "tabs",
    "downloads",
    "storage",
    "webNavigation",
    "<all_urls>"
  ],
  "background": {
    "scripts": ["background.js"],
    "persistent": true
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "run_at": "document_start",
      "all_frames": true
    }
  ]
}
EOF


# ═══════════════════════════════════════════════════════════════════════════
# FILE 5 — extension/background.js
# ═══════════════════════════════════════════════════════════════════════════
echo "[5/6] Generating extension/background.js..."

cat > "$OUTPUT_DIR/extension/background.js" <<EOF
"use strict";
// KIOSK GUARD — background.js
// Generated by generate-firefox-config.sh
// Preseed profile: ${PROFILE_NAME}

// ═══════════════════════════════════════════════════════════════════════
// CONFIGURATION — values driven from preseed.conf
// ═══════════════════════════════════════════════════════════════════════

// PRESEED: ALLOW_DOWNLOADS=${ALLOW_DOWNLOADS}
const DOWNLOADS_ENABLED = ${JS_DOWNLOADS_ENABLED};

// PRESEED: MAX_FILE_SIZE_MB=${MAX_FILE_SIZE_MB}
const MAX_DOWNLOAD_SIZE_MB    = ${MAX_FILE_SIZE_MB};
const MAX_DOWNLOAD_SIZE_BYTES = MAX_DOWNLOAD_SIZE_MB * 1024 * 1024;

// File type categories — driven from preseed ALLOW_* flags
// PRESEED: ALLOW_DOCS=${ALLOW_DOCS}  ALLOW_IMGS=${ALLOW_IMGS}  ALLOW_ARCH=${ALLOW_ARCH}  ALLOW_EXEC=${ALLOW_EXEC}
const ALLOW_DOCS = ${JS_ALLOW_DOCS};   // .pdf .doc .docx .xls .xlsx .ppt .pptx .odt .ods .txt .csv .rtf
const ALLOW_IMGS = ${JS_ALLOW_IMGS};   // .jpg .jpeg .png .gif .webp .bmp .svg .tiff .ico .avif
const ALLOW_ARCH = ${JS_ALLOW_ARCH};   // .zip .tar .gz .bz2 .xz .7z .rar .zst
const ALLOW_EXEC = ${JS_ALLOW_EXEC};   // .exe .msi .bat .cmd .sh .run .AppImage .deb .rpm .apk .bin .ps1 .vbs

// Extension → category map (longest-match first at runtime)
const FILE_TYPE_CATEGORIES = {
  ".pdf":"docs",  ".doc":"docs",  ".docx":"docs", ".xls":"docs",
  ".xlsx":"docs", ".ppt":"docs",  ".pptx":"docs", ".odt":"docs",
  ".ods":"docs",  ".odp":"docs",  ".txt":"docs",  ".csv":"docs",  ".rtf":"docs",
  ".jpg":"imgs",  ".jpeg":"imgs", ".png":"imgs",  ".gif":"imgs",
  ".webp":"imgs", ".bmp":"imgs",  ".svg":"imgs",  ".tiff":"imgs",
  ".ico":"imgs",  ".avif":"imgs",
  ".zip":"arch",  ".tar":"arch",  ".gz":"arch",   ".bz2":"arch",
  ".xz":"arch",   ".7z":"arch",   ".rar":"arch",  ".zst":"arch",
  ".exe":"exec",  ".msi":"exec",  ".bat":"exec",  ".cmd":"exec",
  ".sh":"exec",   ".run":"exec",  ".appimage":"exec", ".deb":"exec",
  ".rpm":"exec",  ".apk":"exec",  ".bin":"exec",  ".com":"exec",
  ".ps1":"exec",  ".vbs":"exec",
};

const CATEGORY_ALLOWED = {
  docs: ALLOW_DOCS,
  imgs: ALLOW_IMGS,
  arch: ALLOW_ARCH,
  exec: ALLOW_EXEC,
};

// PRESEED: LOG_URLS=${LOG_URLS}  LOG_DOWNLOADS=${LOG_DOWNLOADS}
const LOG_TO_STORAGE      = ${JS_LOG_TO_STORAGE};
const MAX_URL_LOG_ENTRIES = 10000;
const MAX_EVT_LOG_ENTRIES = 5000;

// Host log endpoint — POST target for real-time log entries
const LOG_ENDPOINT = "http://127.0.0.1:8888/log";


// ═══════════════════════════════════════════════════════════════════════
// URL Capture
// ═══════════════════════════════════════════════════════════════════════

function captureURL(tabId, url, event) {
  if (!url)                             return;
  if (url.startsWith("about:"))         return;
  if (url.startsWith("moz-extension:")) return;
  if (url.startsWith("chrome:"))        return;
  if (url === "")                       return;

  const entry = {
    timestamp : new Date().toISOString(),
    type      : "url_visit",
    event,
    tabId,
    url,
  };
  storeEntry("urlLog", entry, MAX_URL_LOG_ENTRIES);
  sendToHost(entry);
}

browser.tabs.onCreated.addListener((tab) => {
  if (tab.url) captureURL(tab.id, tab.url, "tab_created");
});

browser.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.url) captureURL(tabId, changeInfo.url, "tab_updated");
});

browser.tabs.onActivated.addListener(({ tabId }) => {
  browser.tabs.get(tabId)
    .then((tab) => { if (tab.url) captureURL(tab.id, tab.url, "tab_activated"); })
    .catch(() => {});
});


// ═══════════════════════════════════════════════════════════════════════
// Download Control
// Check order: (1) global toggle → (2) file type → (3) size limit
// ═══════════════════════════════════════════════════════════════════════

browser.downloads.onCreated.addListener((item) => {

  // Check 1: Global toggle
  if (!DOWNLOADS_ENABLED) {
    cancelDownload(item.id);
    logEvent("download_blocked_toggle", {
      url: item.url, filename: item.filename,
      reason: "Downloads are disabled by policy.",
    });
    return;
  }

  // Check 2: File type filter
  const typeBlock = getFileTypeBlock(item.filename || item.url);
  if (typeBlock) {
    cancelDownload(item.id);
    logEvent("download_blocked_filetype", {
      url: item.url, filename: item.filename,
      category: typeBlock.category, reason: typeBlock.reason,
    });
    return;
  }

  // Check 3: Size limit (skip when totalBytes unknown)
  if (item.totalBytes > 0 && item.totalBytes > MAX_DOWNLOAD_SIZE_BYTES) {
    cancelDownload(item.id);
    const actualMB = (item.totalBytes / (1024 * 1024)).toFixed(1);
    logEvent("download_blocked_size", {
      url: item.url, filename: item.filename,
      actualMB, limitMB: MAX_DOWNLOAD_SIZE_MB,
      reason: \`File is \${actualMB} MB — exceeds the \${MAX_DOWNLOAD_SIZE_MB} MB limit.\`,
    });
    return;
  }

  // All checks passed
  logEvent("download_allowed", {
    url: item.url, filename: item.filename,
    sizeMB: item.totalBytes > 0 ? (item.totalBytes / (1024 * 1024)).toFixed(1) : "unknown",
  });
});

// Returns { category, reason } if the file should be blocked, else null.
function getFileTypeBlock(nameOrUrl) {
  let name = nameOrUrl || "";
  try {
    const u = new URL(nameOrUrl);
    name = u.pathname.split("/").pop() || nameOrUrl;
  } catch (_) {}
  name = name.toLowerCase().split("?")[0];

  const exts = Object.keys(FILE_TYPE_CATEGORIES).sort((a, b) => b.length - a.length);
  for (const ext of exts) {
    if (name.endsWith(ext)) {
      const category = FILE_TYPE_CATEGORIES[ext];
      if (CATEGORY_ALLOWED[category] === false) {
        return { category, reason: \`File type "\${ext}" (category: \${category}) is blocked by policy.\` };
      }
      return null;
    }
  }
  return null; // unknown extension — let host AV handle it
}

// ─── Helpers ────────────────────────────────────────────────────────────

function cancelDownload(id) {
  browser.downloads.cancel(id)
    .then(() => browser.downloads.erase({ id }))
    .catch(() => {});
}

function storeEntry(key, entry, maxEntries) {
  if (!LOG_TO_STORAGE) return;
  browser.storage.local.get(key).then((result) => {
    const log = result[key] || [];
    log.push(entry);
    if (log.length > maxEntries) log.splice(0, log.length - maxEntries);
    browser.storage.local.set({ [key]: log });
  }).catch(() => {});
}

function logEvent(type, data) {
  const entry = { timestamp: new Date().toISOString(), type, ...data };
  storeEntry("eventLog", entry, MAX_EVT_LOG_ENTRIES);
  sendToHost(entry);
}

function sendToHost(entry) {
  fetch(LOG_ENDPOINT, {
    method : "POST",
    headers: { "Content-Type": "application/json" },
    body   : JSON.stringify(entry),
  }).catch(() => {});
}
EOF


# ═══════════════════════════════════════════════════════════════════════════
# FILE 6 — extension/content.js
# ═══════════════════════════════════════════════════════════════════════════
echo "[6/6] Generating extension/content.js..."

cat > "$OUTPUT_DIR/extension/content.js" <<EOF
"use strict";
// KIOSK GUARD — content.js
// Generated by generate-firefox-config.sh
// Preseed profile: ${PROFILE_NAME}
//
// Runs at document_start on every page and frame.
// Intercepts keyboard events before any page script sees them.


// ── Configuration (from preseed) ──────────────────────────────────────
// PRESEED: KIOSK_MODE=${KIOSK_MODE}
// When KIOSK_MODE=yes: all Ctrl combos blocked, Escape blocked.
// When KIOSK_MODE=no:  copy/cut/paste/select-all pass through.

// Ctrl combos that are allowed to pass through (ignored when BLOCK_ALL_CTRL=true)
const ALLOWED_CTRL_KEYS = ${JS_ALLOWED_CTRL_KEYS};

// true = block ALL Ctrl combos including copy/paste (kiosk mode)
// false = allow the keys listed in ALLOWED_CTRL_KEYS
const BLOCK_ALL_CTRL = ${JS_BLOCK_ALL_CTRL};

// Function keys to block (F5 refresh, F11 fullscreen, F12 devtools, etc.)
const BLOCKED_FUNCTION_KEYS = [
  "F1","F2","F3","F4","F5","F6",
  "F7","F8","F9","F10","F11","F12"
];

// PRESEED: KIOSK_MODE=${KIOSK_MODE}
// true = Escape blocked (user cannot dismiss dialogs or exit fullscreen)
const BLOCK_ESCAPE = ${JS_BLOCK_ESCAPE};


// ── Event Interception ────────────────────────────────────────────────
window.addEventListener("keydown", handleKey, true);
window.addEventListener("keyup",   handleKey, true);

function handleKey(event) {
  const ctrl  = event.ctrlKey || event.metaKey;
  const alt   = event.altKey;
  const key   = event.key;
  const keyLo = key.toLowerCase();

  // Block ALL Alt combinations (Alt+F4, Alt+Left/Right, Alt+D, Alt+Home…)
  if (alt) {
    suppress(event);
    return;
  }

  // Ctrl / Cmd combinations
  if (ctrl) {
    if (BLOCK_ALL_CTRL) {
      suppress(event);
      return;
    }
    if (!ALLOWED_CTRL_KEYS.includes(keyLo)) {
      suppress(event);
      return;
    }
    return; // allowed combo — pass through
  }

  // Function keys
  if (BLOCKED_FUNCTION_KEYS.includes(key)) {
    suppress(event);
    return;
  }

  // Escape
  if (BLOCK_ESCAPE && key === "Escape") {
    suppress(event);
    return;
  }
}

function suppress(event) {
  event.preventDefault();
  event.stopPropagation();
  event.stopImmediatePropagation();
}

// NOTE: Browser-chrome shortcuts (Ctrl+T, Ctrl+W, Ctrl+L, Ctrl+Tab) are
// handled by Firefox itself and are NOT reachable from a content script.
// Those are covered by:
//   • policies.json → BlockAboutConfig (blocks Ctrl+L → about:config)
//   • Firefox --kiosk flag (if KIOSK_MODE=yes) → disables Ctrl+W, Ctrl+N, Ctrl+Q
//   • policies.json → DisableDeveloperTools → blocks Ctrl+Shift+I / F12
EOF


# ═══════════════════════════════════════════════════════════════════════════
# BONUS — install.sh (updated for generated output)
# ═══════════════════════════════════════════════════════════════════════════

cat > "$OUTPUT_DIR/install.sh" <<'INSTALLEOF'
#!/bin/bash
# install.sh — Firefox Hardening Installer
# Run INSIDE the Alpine VM as root after Firefox is installed.
# Generated by generate-firefox-config.sh — do not edit manually.

set -e

FIREFOX_BIN="/usr/bin/firefox"
FIREFOX_LIB="/usr/lib/firefox"
POLICY_DIR="$FIREFOX_LIB/distribution"
PREF_DIR="$FIREFOX_LIB/defaults/pref"
EXTENSION_DEST="/opt/kiosk-guard"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "══════════════════════════════════════════════"
echo " Firefox Hardening Installer"
echo "══════════════════════════════════════════════"
echo ""

[ "$EUID" -ne 0 ]          && echo "✖  Run as root." && exit 1
[ ! -f "$FIREFOX_BIN" ]    && echo "✖  Firefox not found. Run: apk add firefox" && exit 1
command -v zip &>/dev/null || apk add --no-cache zip

echo "✔  Firefox found: $FIREFOX_BIN"
echo ""

echo "[1/4] Installing policies.json..."
mkdir -p "$POLICY_DIR"
cp "$SCRIPT_DIR/config/policies.json" "$POLICY_DIR/policies.json"
chmod 644 "$POLICY_DIR/policies.json"

echo "[2/4] Installing autoconfig.js + firefox.cfg..."
mkdir -p "$PREF_DIR"
cp "$SCRIPT_DIR/config/autoconfig.js" "$PREF_DIR/autoconfig.js"
cp "$SCRIPT_DIR/config/firefox.cfg"   "$FIREFOX_LIB/firefox.cfg"
chmod 644 "$PREF_DIR/autoconfig.js" "$FIREFOX_LIB/firefox.cfg"

echo "[3/4] Packaging kiosk-guard extension..."
mkdir -p "$EXTENSION_DEST"
cd "$SCRIPT_DIR/extension"
zip -r "$EXTENSION_DEST/kiosk-guard.xpi" manifest.json background.js content.js
chmod 644 "$EXTENSION_DEST/kiosk-guard.xpi"
cd "$SCRIPT_DIR"

echo "[4/4] Creating Downloads folder..."
mkdir -p /home/browser/Downloads
chown browser:browser /home/browser/Downloads 2>/dev/null || true
chmod 750 /home/browser/Downloads

echo ""
echo "══════════════════════════════════════════════"
echo " Installation complete. Reboot the VM."
echo "══════════════════════════════════════════════"
INSTALLEOF

chmod +x "$OUTPUT_DIR/install.sh"


# ─── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Done. Output written to: $OUTPUT_DIR"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  Files generated:"
echo "    config/policies.json"
echo "    config/autoconfig.js"
echo "    config/firefox.cfg"
echo "    extension/manifest.json"
echo "    extension/background.js"
echo "    extension/content.js"
echo "    install.sh"
echo ""
echo "  Preseed → Firefox mapping applied:"
printf "    %-30s %s\n" "ALLOW_DOWNLOADS"         "→ background.js DOWNLOADS_ENABLED=${JS_DOWNLOADS_ENABLED}"
printf "    %-30s %s\n" "MAX_FILE_SIZE_MB"         "→ background.js MAX_DOWNLOAD_SIZE_MB=${MAX_FILE_SIZE_MB}"
printf "    %-30s %s\n" "ALLOW_DOCS/IMGS/ARCH/EXEC" "→ background.js file type filters"
printf "    %-30s %s\n" "ALLOW_PRIVATE_BROWSING"   "→ policies.json DisablePrivateBrowsing=$(yn_inv "$ALLOW_PRIVATE_BROWSING")"
printf "    %-30s %s\n" "BLOCK_POPUPS"             "→ policies.json PopupBlocking.Default=${POLICY_BLOCK_POPUPS}"
printf "    %-30s %s\n" "DISABLE_DEVTOOLS"         "→ policies.json DisableDeveloperTools=$(yn "$DISABLE_DEVTOOLS")"
printf "    %-30s %s\n" "DISABLE_CONTEXT_MENU"     "→ policies.json DisableRightClick=$(yn "$DISABLE_CONTEXT_MENU")"
printf "    %-30s %s\n" "DISABLE_PASSWORD_SAVING"  "→ firefox.cfg signon prefs=$(yn "$DISABLE_PASSWORD_SAVING")"
printf "    %-30s %s\n" "BLOCK_WEBRTC"             "→ firefox.cfg media.peerconnection=$(yn "$BLOCK_WEBRTC")"
printf "    %-30s %s\n" "KIOSK_MODE"               "→ content.js BLOCK_ALL_CTRL=${JS_BLOCK_ALL_CTRL}"
printf "    %-30s %s\n" "WHITELISTED_DOMAINS"      "→ policies.json WebsiteFilter+PopupAllow"
printf "    %-30s %s\n" "BROWSER_HOMEPAGE"         "→ policies.json Homepage.URL=${HOMEPAGE_URL}"
printf "    %-30s %s\n" "DISABLE_CLIPBOARD_SHARING" "→ firefox.cfg clipboardevents=$(yn "$DISABLE_CLIPBOARD_SHARING")"
printf "    %-30s %s\n" "PERSIST_COOKIES/HISTORY"  "→ policies.json SanitizeOnShutdown=${POLICY_SANITIZE}"
printf "    %-30s %s\n" "HTTP_HTTPS_ONLY"          "→ policies.json HttpsOnlyMode=$(yn "$HTTP_HTTPS_ONLY")"
printf "    %-30s %s\n" "FORCE_PROXY"              "→ firefox.cfg network.proxy.* prefs"
printf "    %-30s %s\n" "ALLOW_EXTENSIONS"         "→ policies.json ExtensionSettings mode"
printf "    %-30s %s\n" "EXTENSION_WHITELIST"      "→ policies.json force_installed entries"
printf "    %-30s %s\n" "LOG_URLS"                 "→ background.js LOG_TO_STORAGE=${JS_LOG_TO_STORAGE}"
printf "    %-30s %s\n" "SITE_ACCESS_MODE"         "→ policies.json WebsiteFilter block/allow"
echo ""
echo "  Next steps:"
echo "    1. scp -r $OUTPUT_DIR browser@<vm-ip>:~/"
echo "    2. Inside VM: sudo bash ~/$(basename "$OUTPUT_DIR")/install.sh"
echo "    3. Reboot the VM"
echo ""
