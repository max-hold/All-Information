# Firefox Hardening — Verification Guide
# Run these tests INSIDE the Alpine VM after install.sh and reboot.
# Each test tells you exactly what to do, what to expect if WORKING,
# and what to check if it FAILS.
# ═══════════════════════════════════════════════════════════════════════════


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
BEFORE YOU START — Confirm the extension loaded
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Open Firefox.
Step 2: Type this in the address bar and press Enter:
        about:support

Step 3: Scroll down to "Extensions" section.

✔ PASS — You see "Kiosk Guard" listed with status "enabled"
✖ FAIL — Extension not listed → policies.json not loaded or XPI path wrong
         Fix: Check that /opt/kiosk-guard/kiosk-guard.xpi exists
              Run: ls -la /opt/kiosk-guard/


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 1 — URL Capture
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST A — Check local extension storage (always works, no host needed)

Step 1: Open Firefox.
Step 2: Go to any website. Example: https://www.google.com
Step 3: Open a second tab. Go to: https://www.wikipedia.org
Step 4: Open a THIRD tab. Type this URL and press Enter:
        about:debugging#/runtime/this-firefox

Step 5: Click "Inspect" next to "Kiosk Guard"
Step 6: In the debugger window that opens, click the "Console" tab
Step 7: Paste this command and press Enter:
        browser.storage.local.get("urlLog").then(r => console.log(JSON.stringify(r.urlLog, null, 2)))

✔ PASS — You see a JSON list with entries containing:
         - "type": "url_visit"
         - "url": "https://www.google.com/" (and wikipedia)
         - "event": "tab_updated" or "tab_activated"
         - "timestamp": a real date/time

✖ FAIL — Empty result [] or undefined
         Fix: Extension is not loaded. Check the "Before you start" step above.


TEST B — Check host endpoint is receiving (once host controller is running)

Step 1: On the HOST machine, start a simple listener:
        python3 -m http.server 8888

Step 2: Inside VM, open any website.
Step 3: Check host terminal — you should see incoming POST requests logged.

✔ PASS — POST requests appear in host terminal for every URL visited
✖ FAIL — No requests → host endpoint not running, or VM network not reaching host
         This is expected until your host controller service is built.
         Local storage log (Test A) is always the fallback.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 2 — Download Toggle (Disabled by Default)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST — Try to download any file while downloads are disabled

Step 1: Open Firefox.
Step 2: Go to: https://www.7-zip.org/download.html
Step 3: Click any download link.

✔ PASS — Download immediately fails. Nothing is saved. No download bar appears.
         You may see a brief "failed" flash in the download indicator.

✖ FAIL — File starts downloading
         Fix: Check firefox.cfg line is NOT commented out:
              Run: grep "forbid_open_with" /usr/lib/firefox/firefox.cfg
              Should show: lockPref("browser.download.forbid_open_with", true);


TEST — Enable downloads and confirm they work

Step 1: Edit firefox.cfg:
        nano /usr/lib/firefox/firefox.cfg

Step 2: Find this line:
        lockPref("browser.download.forbid_open_with", true);

Step 3: Add // at the start:
        // lockPref("browser.download.forbid_open_with", true);

Step 4: Save and RESTART Firefox (close and reopen).
Step 5: Try downloading a small file from https://www.7-zip.org/download.html

✔ PASS — Download works normally and file appears in /home/browser/Downloads
✖ FAIL — Still blocked → Firefox not restarted, or file not saved correctly


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 3 — Download Size Limit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

IMPORTANT: Downloads must be ENABLED first (Feature 2 toggle set to true).

TEST A — Try a file LARGER than the limit (should be blocked)

Step 1: Make sure DOWNLOADS_ENABLED = true in background.js and reinstalled.
Step 2: Go to: https://releases.ubuntu.com/
Step 3: Click any Ubuntu ISO download link (~1.5 GB or more).
        If your limit is set to 1 GB, this will be blocked.
        If your limit is 5 GB, use a larger file URL.

✔ PASS — Download is immediately cancelled. File does not appear in /home/browser/Downloads.
         Check the event log to confirm:
         In about:debugging → Kiosk Guard Console:
         browser.storage.local.get("eventLog").then(r => console.log(JSON.stringify(r.eventLog?.slice(-5), null, 2)))
         You should see: "type": "download_blocked_size"

✖ FAIL — Large file downloads anyway
         Fix: Check DOWNLOADS_ENABLED = true AND extension was repackaged after editing


TEST B — Try a file SMALLER than the limit (should succeed)

Step 1: Go to: https://www.7-zip.org/download.html
Step 2: Download the small 7-Zip installer (~1.5 MB — well under 5 GB limit).

✔ PASS — Small file downloads successfully
✖ FAIL — Small file also blocked → check DOWNLOADS_ENABLED = true in background.js


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 4 — Keyboard Shortcuts Disabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST — Try every major shortcut category

Open any webpage (e.g. https://www.google.com) and try each:

  Shortcut          Expected result if WORKING
  ──────────────────────────────────────────────────────────────
  Ctrl + T          Nothing happens  (new tab blocked)
  Ctrl + W          Nothing happens  (close tab blocked)
  Ctrl + R          Nothing happens  (refresh blocked)
  Ctrl + L          Nothing happens  (address bar focus blocked)
  Ctrl + H          Nothing happens  (history blocked)
  Ctrl + J          Nothing happens  (downloads panel blocked)
  Ctrl + Shift + I  Nothing happens  (DevTools blocked — also by policies)
  F5                Nothing happens  (refresh blocked)
  F12               Nothing happens  (DevTools blocked — also by policies)
  F11               Nothing happens  (fullscreen blocked)
  Alt + Left        Nothing happens  (back navigation blocked)
  Alt + Right       Nothing happens  (forward navigation blocked)
  Alt + F4          Nothing happens  (close window blocked)
  Ctrl + C          Works normally   (copy — in ALLOWED_CTRL_KEYS)
  Ctrl + V          Works normally   (paste — in ALLOWED_CTRL_KEYS)
  Ctrl + A          Works normally   (select all — in ALLOWED_CTRL_KEYS)

✔ PASS — Blocked shortcuts do nothing. Allowed ones (copy/paste) still work.
✖ FAIL — Shortcuts still work
         Fix: Content script not loaded. Check extension loaded (Before you start step).
         Note: Ctrl+T and Ctrl+W are browser-chrome level — if those still work,
               it means Firefox was NOT launched with the --kiosk flag.
               Add --kiosk to your Firefox launch command.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 5 — Privacy Hardening (WebRTC, Telemetry, Fingerprinting)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST A — WebRTC disabled (no IP leak)

Step 1: Go to: https://browserleaks.com/webrtc
✔ PASS — Page shows "WebRTC is disabled" or no IP addresses are listed
✖ FAIL — Real IP address is shown → firefox.cfg not loaded correctly

TEST B — Telemetry disabled

Step 1: Type in address bar:  about:telemetry
✔ PASS — Page shows no data being collected or "Telemetry is disabled"
✖ FAIL — Active telemetry data shown → firefox.cfg lockprefs not applied

TEST C — Tracking protection active

Step 1: Go to: https://coveryourtracks.eff.org
Step 2: Click "Test Your Browser"
✔ PASS — Shows "Strong Protection" or trackers blocked
✖ FAIL — Weak protection shown → check privacy.trackingprotection lines in firefox.cfg


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 6 — about:config Disabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Type in address bar:  about:config
Step 2: Press Enter.

✔ PASS — Page shows "This page has been disabled" or redirects away
✖ FAIL — about:config opens normally
         Fix: Check policies.json is in the right place:
              ls -la /usr/lib/firefox/distribution/policies.json


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 7 — Developer Tools Disabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Open any webpage.
Step 2: Right-click anywhere on the page.

✔ PASS — "Inspect" option is MISSING from the right-click menu
✖ FAIL — "Inspect" is still there → policies.json not loaded

Step 3: Also try pressing F12 — should do nothing.
Step 4: Also try the Firefox menu (hamburger ≡) → "More Tools" — should be missing.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 8 — Extension Installation Locked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Go to: https://addons.mozilla.org
Step 2: Try to install any extension. Click "Add to Firefox" on any extension.

✔ PASS — Firefox shows a message:
         "Extension installation is not permitted on this system."
         Or the button is greyed out / does nothing.

✖ FAIL — Extension installs normally
         Fix: policies.json ExtensionSettings block not loaded correctly


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 9 — Firefox Sync / Accounts Disabled
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 1: Click the Firefox menu (hamburger ≡, top right).

✔ PASS — "Sign in to Sync" option is MISSING from the menu entirely.
✖ FAIL — Sync option is visible → policies.json not applied

Step 2: Type in address bar:  about:preferences#sync
✔ PASS — Page is blank or shows "Sync has been disabled by your administrator"
✖ FAIL — Full Sync settings page opens


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FEATURE 10 — Internal Firefox Pages Blocked
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Test each URL in the address bar:

  URL                    Expected result
  ──────────────────────────────────────────────────────────────
  about:profiles         Blocked — "page has been disabled"
  about:addons           Blocked or empty — no extension manager
  about:preferences      Allowed (basic settings OK to access)
  about:support          Allowed (you need this for debugging)

✔ PASS — Blocked pages show an error or redirect
✖ FAIL — Pages open normally → policies.json not loaded


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MASTER CHECKLIST — Quick Pass/Fail Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Run through this in order. Mark each one:

  [ ] PRE   — Extension "Kiosk Guard" appears in about:support
  [ ]  1    — URL log has entries after visiting 2 websites
  [ ]  2    — Download fails immediately when toggle is off
  [ ]  3    — Large file (over limit) is blocked, small file passes
  [ ]  4    — Ctrl+R, F5, F12, Alt+Left all do nothing
  [ ]  5    — browserleaks.com/webrtc shows WebRTC disabled
  [ ]  6    — about:config shows "page disabled"
  [ ]  7    — Right-click menu has no "Inspect" option
  [ ]  8    — addons.mozilla.org install button blocked
  [ ]  9    — Sync option missing from Firefox menu
  [ ] 10    — about:profiles blocked


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MOST COMMON FAILURE — policies.json not loading
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If features 6, 7, 8, 9, 10 all fail at once — policies.json is not being read.

Run these checks from terminal inside the VM:

  # 1. Confirm the file is there
  ls -la /usr/lib/firefox/distribution/policies.json

  # 2. Confirm Firefox can see it (look for "policies" line)
  firefox --headless --screenshot /tmp/test.png about:support 2>&1 | head -20

  # 3. Verify the JSON is valid (no syntax errors)
  python3 -c "import json; json.load(open('/usr/lib/firefox/distribution/policies.json')); print('JSON valid')"

  # 4. Check Firefox sees the policy at runtime
  # Open Firefox → address bar → about:policies
  # Should list all your active policies

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MOST COMMON FAILURE — firefox.cfg not loading
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If feature 5 (WebRTC, telemetry) and feature 2 (download toggle) fail:

  # 1. Confirm both files exist
  ls -la /usr/lib/firefox/firefox.cfg
  ls -la /usr/lib/firefox/defaults/pref/autoconfig.js

  # 2. Check autoconfig.js has the right filename
  cat /usr/lib/firefox/defaults/pref/autoconfig.js
  # Must show: pref("general.config.filename", "firefox.cfg");

  # 3. Check the FIRST LINE of firefox.cfg is a comment
  head -1 /usr/lib/firefox/firefox.cfg
  # Must start with // — Firefox silently ignores the file if line 1 is not a comment
