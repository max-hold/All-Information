# A Kiosk wizard 
- Basically a configuration interface that asks the user questions, writes config files, and optionally installs or rebuilds the system.
- Wizard UI → asks questions
- Config generator → writes files
- Installer/apply script → applies settings

## Architecture of your kiosk wizard
```
wizard.sh
├── network.sh
├── browser.sh
├── security.sh
├── system.sh
└── build.sh
```

## Flow:
```
Start wizard
   ↓
Ask config questions
   ↓
Save answers to config file
   ↓
Generate kiosk configs
   ↓
Apply or build image
```

## Folder structure
```
mykiosk/
├── wizard.sh
├── config/
│   └── kiosk.conf
├── templates/
│   ├── firefox-policies.json
│   ├── autostart.desktop
│   └── cage.service
├── scripts/
│   ├── apply_browser.sh
│   ├── apply_network.sh
│   ├── apply_security.sh
│   └── install.sh
kiosk.conf
```

## Create wizard.sh And kiosk.conf
```
nano wizard.sh
```

```
#!/bin/bash

CONFIG_FILE="./config/kiosk.conf"

mkdir -p config

clear
echo "=================================="
echo "      MyKiosk Configuration"
echo "=================================="

read -p "Homepage URL: " HOMEPAGE
read -p "Enable fullscreen kiosk? (yes/no): " FULLSCREEN
read -p "Disable downloads? (yes/no): " DOWNLOADS
read -p "Allowed domains (comma separated): " WHITELIST
read -p "Auto clear session on reboot? (yes/no): " CLEAR_SESSION

cat > "$CONFIG_FILE" <<EOF
HOMEPAGE="$HOMEPAGE"
FULLSCREEN="$FULLSCREEN"
DOWNLOADS="$DOWNLOADS"
WHITELIST="$WHITELIST"
CLEAR_SESSION="$CLEAR_SESSION"
EOF

echo ""
echo "Configuration saved to $CONFIG_FILE"

read -p "Apply configuration now? (yes/no): " APPLY

if [ "$APPLY" = "yes" ]; then
    ./scripts/install.sh
fi
```

```
doas chmod +x wizard.sh
```
```
doas sh ./wizard.sh
```

- After running check
```
cat config/kiosk.conf
```

- contains:
```
HOMEPAGE="https://example.com"
FULLSCREEN="yes"
DOWNLOADS="yes"
WHITELIST="example.com,openai.com"
CLEAR_SESSION="yes"
```



## Install/apply script
```
nano scripts/install.sh
```
```
#!/bin/bash

source ./config/kiosk.conf

echo "Applying browser config..."
./scripts/apply_browser.sh

echo "Applying security config..."
./scripts/apply_security.sh

echo "Done."
```

## Firefox config generator
- This auto-generates browser policies.
```
nano scripts/apply_browser.sh
```

```
#!/bin/bash
source ./config/kiosk.conf

mkdir -p /etc/firefox/policies

cat > /etc/firefox/policies/policies.json <<EOF
{
  "policies": {
    "Homepage": {
      "URL": "$HOMEPAGE",
      "StartPage": "homepage"
    },
    "DisablePrivateBrowsing": true,
    "DisableFirefoxAccounts": true,
    "DisablePocket": true
  }
}
EOF
```

## Security config
```
nano scripts/apply_security.sh
```

```
#!/bin/bash
source ./config/kiosk.conf

if [ "$CLEAR_SESSION" = "yes" ]; then
    echo "tmpfs /tmp tmpfs defaults,noatime 0 0" >> /etc/fstab
fi
```

## Browser autostart
```
mkdir -p ~/.config/autostart
```

```
nano ~/.config/autostart/firefox.desktop
```

```
[Desktop Entry]
Type=Application
Exec=firefox --kiosk https://example.com
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Firefox Kiosk
```

# Future features (recommended)
- Network settings
        DHCP/static IP
        proxy config
- Browser restrictions
        disable right click
        disable dev tools
        disable file picker
- System lockdown
        disable TTY switching
        disable Ctrl+Alt+F1
        disable reboot shortcuts
- Whitelist engine
        only allow approved domains

## A good project name
- OpenKiosk
- GhostKiosk
- KioskForge


