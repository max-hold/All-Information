# Files the script expects
- The script looks for these files relative to where you run ./install.sh:
$SCRIPT_DIR/
├── config/
│   ├── policies.json          # ← Most important
│   ├── autoconfig.js
│   └── firefox.cfg
└── extension/
    ├── manifest.json
    ├── background.js
    └── content.js
    
It will:
- Copy `config/policies.json` → `/usr/lib/firefox/distribution/policies.json`
- Copy `config/autoconfig.js` → `/usr/lib/firefox/defaults/pref/autoconfig.js`
- Copy `config/firefox.cfg` → `/usr/lib/firefox/firefox.cfg`
- Zip the three files in `extension/` into `/opt/kiosk-guard/kiosk-guard.xpi`
- Create `/home` `/browser` `/Downloads`



# Features update or New Feature

- Disabling all keyboard shortcuts via a content script (content.js) is aggressive and can be fragile (it usually works by capturing keydown events, but some browser-level shortcuts like Ctrl+Shift+I, F12, or Alt-menu can bypass it).

- write click disable 

- URL logging per tab (Feature 1) via extension is useful for auditing, but make sure the logging doesn't become a privacy/security risk itself (where are the logs written? rotated? encrypted?).

- No AppArmor (as noted) — on Alpine you might want to consider firejail or proper seccomp/namespace isolation instead.

- [ The script assumes a user named browser exists. It should probably check/create the user or make it configurable. ]

- **Note**: The extension ID in the policy must match the `browser_specific_settings` or `applications key` in `manifest.json`

- Disable the all `about:<url>` form accessing 



