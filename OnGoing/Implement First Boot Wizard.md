# Implement First-Boot Wizard

## Install Tools for the Wizard (inside your running Alpine VM)
```
apk update
apk add dialog jq # Best for text-based wizard (TUI), jq for easy JSON handling
```

## Create the Wizard Script
- Create the main script:
```
mkdir -p /usr/local/bin
cat > /usr/local/bin/firstboot-wizard.sh << 'EOF'
#!/bin/sh

CONFIG_FILE="/etc/browser-config.json"
DONE_FILE="/etc/firstboot_done"

if [ -f "$DONE_FILE" ]; then
    echo "First boot already completed."
    exit 0
fi

# Welcome
dialog --title "Secure Browser Isolation Setup" --msgbox "Welcome to the Secure Firefox VM Setup Wizard.\n\nPlease configure your preferences." 10 60

# ==================== PHASE 1: Main Options (Checkboxes) ====================
CHOICES=$(dialog --title "Feature Configuration" --checklist \
"Select the features you want to enable:" 18 70 10 \
    1 "Enable File Downloads" on \
    2 "Capture All URLs (Logging)" on \
    3 "Enable Copy-Paste (Host <-> VM)" off \
    4 "Whitelist Mode (Only allow specific URLs)" off \
    5 "Kiosk Mode (Full Screen, No UI)" on 3>&1 1>&2 2>&3)

# Parse choices
ENABLE_DOWNLOADS=$(echo "$CHOICES" | grep -q "1" && echo true || echo false)
ENABLE_URL_CAPTURE=$(echo "$CHOICES" | grep -q "2" && echo true || echo false)
ENABLE_COPYPASTE=$(echo "$CHOICES" | grep -q "3" && echo true || echo false)
WHITELIST_MODE=$(echo "$CHOICES" | grep -q "4" && echo true || echo false)
KIOSK_MODE=$(echo "$CHOICES" | grep -q "5" && echo true || echo false)

# ==================== PHASE 2: Whitelist URLs (Conditional) ====================
WHITELIST_URLS=""

if [ "$WHITELIST_MODE" = "true" ]; then
    dialog --title "Whitelist URLs" --msgbox "You enabled Whitelist Mode.\n\nEnter allowed domains/URLs (one per line).\nExample:\ngoogle.com\nexample.org" 10 60
    
    TEMP_URLS=$(dialog --title "Enter Allowed URLs" --inputbox "Enter URLs (one per line):" 15 70 "" 3>&1 1>&2 2>&3)
    
    if [ -n "$TEMP_URLS" ]; then
        WHITELIST_URLS=$(echo "$TEMP_URLS" | tr '\n' ',' | sed 's/,$//')
    fi
fi

# ==================== Save Configuration as JSON ====================
cat > "$CONFIG_FILE" << EOF
{
  "firefox": {
    "downloads_enabled": $ENABLE_DOWNLOADS,
    "url_capture": $ENABLE_URL_CAPTURE,
    "copypaste_enabled": $ENABLE_COPYPASTE,
    "kiosk_mode": $KIOSK_MODE,
    "whitelist_mode": $WHITELIST_MODE,
    "allowed_urls": "$WHITELIST_URLS"
  },
  "network": {
    "capture_traffic": $ENABLE_URL_CAPTURE,
    "log_path": "/downloads/logs"
  }
}
EOF

dialog --title "Success" --msgbox "Configuration saved successfully!\n\nThe system will now apply settings and prepare for first use." 10 60

touch "$DONE_FILE"

# Apply configurations
sh /usr/local/bin/apply-config.sh

exit 0
EOF
```
```
chmod +x /usr/local/bin/firstboot-wizard.sh
```

## Create Apply Script (configs → real files)
```
#!/bin/sh
CONFIG="/etc/browser-config.json"

mkdir -p /usr/lib/firefox/distribution

# Generate Firefox policies.json
cat > /usr/lib/firefox/distribution/policies.json << EOF
{
  "policies": {
    "Kiosk": $(jq -r '.firefox.kiosk_mode' "$CONFIG"),
    "DisablePrivateBrowsing": false,
    "DownloadRestrictions": $(jq -r '.firefox.downloads_enabled' "$CONFIG" | grep -q true && echo '[]' || echo '["*"]')
  }
}
EOF

# TODO: Add more logic later
# - Whitelist URLs → Firefox policies or proxy rules
# - iptables rules
# - AppArmor
# - Copy-paste (virtio or spice)

echo "✅ All configurations applied."
```
```
chmod +x /usr/local/bin/apply-config.sh
```

## Create OpenRC Service (runs only once)
```
cat > /etc/init.d/firstboot-wizard << 'EOF'
#!/sbin/openrc-run

name="firstboot_wizard"
command="/usr/local/bin/firstboot-wizard.sh"

depend() {
    after localmount
    before display-manager   # or before firefox-kiosk
}

start() {
    ebegin "Running First-Boot Wizard"
    $command
    eend $?
    
    # Self-disable
    rc-update del firstboot-wizard default
}
EOF
```
```
chmod +x /etc/init.d/firstboot-wizard
rc-update add firstboot-wizard default
```

## Test the Wizard
Reboot your current VM:
```
reboot
```

- It should now run the wizard automatically on boot.
- After finishing, it creates `/etc/firstboot_done` and disables itself.
