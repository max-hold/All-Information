# A locked-down browser config
- Browser policies (disable risky features)
- Launch flags (force kiosk behavior)
- OS restrictions (stop escaping the browser)


1. Firefox enterprise policies
Create:
```
sudo mkdir -p /etc/firefox/policies
sudo nano /etc/firefox/policies/policies.json
```
Paste:
```
{
  "policies": {
    "Homepage": {
      "URL": "https://google.com",
      "StartPage": "homepage",
      "Locked": true
    },
    "BlockAboutConfig": true,
    "AppAutoUpdate": false,
    "DisableAppUpdate": true,
    "DisableFeedbackCommands": true,
    "DisableFirefoxAccounts": true,
    "DisableFirefoxStudies": true,
    "DisableForgetButton": true,
    "DisableDeveloperTools": true,
    "DisableFormHistory": true,
    "DisableMasterPasswordCreation": true,
    "DisablePasswordReveal": true,
    "DisablePocket": true,
    "DisablePrivateBrowsing": true,
    "DisableProfileImport": true,
    "DisableProfileRefresh": true,
    "DisableSafeMode": true,
    "DisableSecurityBypass": true,
    "DisableSetDesktopBackground": true,
    "DisableSystemAddonUpdate": true,
    "DisableTelemetry": true,
    "DontCheckDefaultBrowser": true,
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "PromptForDownloadLocation": false,
    "DownloadDirectory": "/tmp/downloads",
    "Permissions": {
      "Camera": {
        "BlockNewRequests": true
      },
      "Microphone": {
        "BlockNewRequests": true
      },
      "Location": {
        "BlockNewRequests": true
      },
      "Notifications": {
        "BlockNewRequests": true
      }
    },
    "PopupBlocking": {
      "Default": true,
      "Locked": true
    },
    "WebsiteFilter": {
      "Block": ["*"],
      "Exceptions": ["https://allowed-site.com"]
    },
    "Preferences": {
      "browser.download.useDownloadDir": {
        "Value": true,
        "Status": "locked"
      },
      "browser.download.manager.showWhenStarting": {
        "Value": false,
        "Status": "locked"
      },
      "browser.tabs.closeWindowWithLastTab": {
        "Value": false,
        "Status": "locked"
      },
      "browser.aboutConfig.showWarning": {
        "Value": false,
        "Status": "locked"
      },
      "browser.shell.checkDefaultBrowser": {
        "Value": false,
        "Status": "locked"
      },
      "dom.disable_open_during_load": {
        "Value": true,
        "Status": "locked"
      }
    }
  }
}
```

This handles:
        homepage lock
        no password saving
        no updates
        no telemetry
        no permissions prompts
        reduced download abuse
        
        
2. Launch Firefox in kiosk mode
```
firefox \
  --kiosk \
  --private-window \
  --no-remote \
  https://google.com
```


3. Disable shortcuts (Disable at OS level)
- Users usually escape using:
        Alt+Tab
        Ctrl+Alt+T
        Ctrl+Alt+F1-F12
        Super key
        Ctrl+W
        Ctrl+L

- Example with X11:
```
setxkbmap -option
xmodmap -e "keycode 133 = NoSymbol"
xmodmap -e "keycode 64 = NoSymbol"
```
This disables:
        Super
        Alt

- Disable VT switching:
```
sudo nano /etc/systemd/logind.conf
```

```
NAutoVTs=0
ReserveVT=0
```


4. Disable TTY switching (important)
```
systemd.mask=getty@tty1.service
```
Or:
```
sudo systemctl mask getty@tty1.service
sudo systemctl mask getty@tty2.service
```
- Repeat for others services.


5. Disable right click + context menus
- Inside Firefox prefs:
Add:
```
"Preferences": {
  "dom.event.contextmenu.enabled": {
    "Value": false,
    "Status": "locked"
  }
}
```


6. Disable downloads completely
- Safer than redirecting to /tmp is disabling UI access.
Add:
```
"Permissions": {
  "FilePicker": {
    "BlockNewRequests": true
  }
}
```
And:
```
"Preferences": {
  "browser.download.forbid_open_with": {
    "Value": true,
    "Status": "locked"
  }
}
```

7. Auto restart browser if closed
```
sudo nano /etc/systemd/system/kiosk.service
```

```
[Unit]
Description=Firefox Kiosk

[Service]
User=kiosk
ExecStart=/usr/bin/firefox --kiosk https://example.com
Restart=always
RestartSec=2

[Install]
WantedBy=graphical.target
```
```
sudo systemctl enable kiosk.service
```


9. Whitelist domains only (recommended)
- Browser policies don’t fully solve this.
- Use firewall:
```
sudo iptables -P OUTPUT DROP
sudo iptables -A OUTPUT -p tcp -d example.com --dport 443 -j ACCEPT
```

- DNS filtering (much stronger than browser-only filtering.)


10. Disable terminal access
- Be careful with that one unless you have another admin route.
```
sudo usermod -s /usr/sbin/nologin kiosk
```
Or:
```
sudo passwd -l root
```


