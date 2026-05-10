# This is designed around your earlier goals:
		minimal OS
		browser-only appliance
		disposable sessions
		hard lockdown
		small footprint (~200MB–800MB realistic depending on browser)


1. High-Level Architecture
Bootloader
   ↓
Minimal Linux OS
   ↓
Read-only root filesystem
   ↓
Overlay/tmpfs writable layer
   ↓
Auto-login restricted user
   ↓
Window manager / compositor
   ↓
Hardened browser launcher
   ↓
Policy engine + config manager
   ↓
Session cleanup/reset


2. Core System Layers
## A. Base OS Layer
Purpose:
		minimal immutable system
		fast boot
		hard to tamper with

Recommended:
### Alpine Linux (best)
Pros:
		tiny
		musl
		OpenRC
		small ISO

Components:
		kernel
		busybox
		OpenRC
		squashfs
		overlayfs

Expected size:
		150–300MB before browser


## Filesystem design
### Read-only root
Mount:
```
/ ro
```

Benefits:
		persistence blocked
		malware cleanup by reboot

### Writable overlay
Use:
		overlayfs
		tmpfs

Example:
```
lowerdir=/ro
upperdir=/tmp/upper
workdir=/tmp/work
```

Result:
		writes disappear after reboot

## Persistent config partition (optional)
Small persistent partition:
```
/config
```

Stores only:
		config.json
		certificates
		policies
		network settings


3. Boot Process
## Bootloader
Use:
		GRUB
  or
		syslinux

Boot options:
		quiet
		splash
		lockdown mode

Kernel args:
```
quiet loglevel=3 mitigations=auto
```

Optional:
		disable recovery shell

## Auto login
Restricted user:
```
kiosk
```

No password login.
Autologin:
		tty1


4. Display Layer
### Cage
- Single-app kiosk compositor.
Pros:
		ideal kiosk
		tiny
		secure

Launches one app only.
Excellent for hard lockdown.

Architecture:
```
systemd
  → cage
      → browser
```
	

5. Browser Layer
## Chromium (recommended)
Why:
		kiosk flags
		enterprise policies
		extension support
		
Launch:
```
chromium \
  --kiosk \
  --incognito \
  --no-first-run \
  --disable-sync \
  --disable-translate \
  --disable-extensions
```


6. Policy Engine
- This is your “enterprise control plane”.
Store:
```
/etc/kiosk/policy.json
```

Example:
```json
{
  "homepage": "https://portal.company.com",
  "whitelist": [
    "portal.company.com",
    "mail.company.com"
  ],
  "downloads": false,
  "clipboard": false,
  "devtools": false
}
```

## Policy modules
### URL filtering
- Allow only approved domains.
    
Implement:
		proxy filter
  or
		browser extension
  or
		DNS filtering

Rules:
		whitelist
		blacklist
		regex rules

### Download control
Disable:
		downloads
		save dialogs

### Upload control
- Useful for secure terminals.
Can block:
		file picker
		uploads

### Clipboard control
- Can use browser policies/extensions.
Disable:
		copy
		paste
	
### Print control
Disable:
		Ctrl+P
		print dialogs

### Extension policy
		disable installs
		force whitelist

### DevTools blocking
Disable:
		F12
		Ctrl+Shift+I
		inspect


7. Input Lockdown
- Critical.

## Disable key combos
Block:
		Alt+Tab
		Ctrl+Alt+Fx
		Ctrl+Alt+Del
		Super key
		F1–F12 if needed

Tools:
		interception-tools
		keyd
		xmodmap
		evdev filters

## Disable virtual terminals
Kernel:
```
vt.global_cursor_default=0
```

system:
```
dontVTSwitch
```

and disable:
```
Ctrl+Alt+F1-F12
```

## Disable magic SysRq
```
echo 0 > /proc/sys/kernel/sysrq
```


8. Session Management
- This is where your system becomes enterprise-grade.

## Ephemeral browser profile
Browser profile in tmpfs:
```
/tmp/browser-profile
```

Every launch:
		fresh profile

## Session timeout
- Auto logout after inactivity.
Example:
		15 mins

Can:
		close browser
		reset session

## Session reset triggers
Reset on:
		browser exit
		timeout
		reboot
		admin command

Cleanup:
```
rm -rf /tmp/*
```


9. Network Controls
## DNS filtering
- Can block domains.
Use:
		dnsmasq
		unbound

## Firewall
Use: 
        nftables/iptables:

Allow:
		80
		443
		DNS
- Block everything else.

## Proxy support
Optional:
		corporate proxy
		authentication proxy

## Certificate injection
- Install enterprise root certs.
Useful for:
		SSL inspection
		internal PKI


10. Admin Mode
- Need safe maintenance.

## Hidden admin unlock
Hotkey:
```
Ctrl+Alt+A
```
  ↓
Password prompt.
  ↓
Enters admin shell.

## Admin features:
		network config
		update config
		logs
		diagnostics

## Separate admin UI
- Minimal local web UI.
Can edit:
		Wi-Fi
		homepage
		whitelist
		updates


11. Logging / Audit
- Optional enterprise features.
Log:
		URL access
		blocked sites
		session starts
		downloads attempted

Store:
		local logs
  or
		remote syslog


12. Remote Management (Enterprise-like)

## Config pull
At boot:
```
https://server/config.json
```
  ↓
Fetch policies.

## Heartbeat
Device reports:
		online/offline
		version
		IP
		uptime

## Remote commands
Can trigger:
		reboot
		reset
		update


13. Security Hardening

## Kernel hardening
Enable:
		ASLR
		seccomp
		namespaces

## Disable unnecessary services
Disable:
		ssh (unless admin)
		bluetooth
		avahi
		cups

## Sandbox browser
- Extra isolation.
Use:
		bubblewrap
		firejail
		namespaces

14. Build Wizard
- Web wizard or TUI:

### Step 1
Choose browser:
		Chromium
		Firefox

### Step 2
Homepage

### Step 3
Whitelist URLs

### Step 4
Enable/disable:
		downloads
		clipboard
		printing
		uploads

### Step 5
Network config

### Step 6
Admin password

### Step 7
Generate ISO

Output:
		bootable ISO
		IMG
		VM image



# Feature Checklist
## Core kiosk
		[ ] fullscreen kiosk
		[ ] auto boot browser
		[ ] no desktop
		[ ] no shell
		[ ] auto login

## Security
		[ ] readonly root
		[ ] overlayfs
		[ ] tmpfs profile
		[ ] browser sandbox
		[ ] firewall

## Browser controls
		[ ] URL whitelist
		[ ] disable downloads
		[ ] disable uploads
		[ ] disable extensions
		[ ] disable devtools
		[ ] disable print

## Input lockdown
		[ ] block shortcuts
		[ ] disable VT switching
		[ ] disable SysRq

## Session
		[ ] reset on reboot
		[ ] reset on exit
		[ ] inactivity timeout

## Enterprise
		[ ] remote config
		[ ] logging
		[ ] signed updates
		[ ] remote management

## Builder
		[ ] config wizard
		[ ] ISO generator

		

15. Suggested Project Stack
### OS
		Alpine Linux

### Display
		Cage (Wayland)

### Browser
		Chromium

### Hardening
		bubblewrap + seccomp

### Filesystem
		squashfs + overlayfs

### Init
		OpenRC

### Build
		mkimage.sh

### Config
		JSON policies

### ISO
		xorriso


# Final architecture
```
Alpine Linux
 + squashfs readonly root
 + overlayfs tmpfs
 + OpenRC
 + Cage
 + Chromium kiosk
 + JSON policies
 + session reset
 + config wizard
 + ISO builder
```


# Your should focus on:
1. boot
2. browser lockdown
3. ephemeral sessions
4. config wizard

