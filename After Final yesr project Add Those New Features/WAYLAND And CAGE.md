[THE `CAGE` HAS AN ERROR WHEN IT START, THE SYSTEM IS AUTOMATICALLY LOGIN TO THE USER BUT CAN'T RUN THE CAGE]
# kernel + init + networking + Wayland compositor + browser

## Architecture
→ Bootloader
→ Alpine Linux
→ Auto login kiosk user
→ Wayland
→ Cage (single-app compositor)
→ Browser in kiosk mode

## Core components:
Alpine Linux
OpenRC
Wayland
Cage
Browser
Locked user
Read-only/ephemeral session


1. Install Alpine base
disk mode: `sys`
hostname: `mykiosk`


2. Install packages
```
apk update
apk add \
  wayland \
  cage \
  seatd \
  chromium \
  dbus \
  eudev \
  font-noto \
  mesa-dri-gallium
```
verify the chromium install
```
which chromium-browser
```

3. Create kiosk user
```
adduser -D -s /bin/sh kiosk
```

4. Enable services
```
rc-update add seatd
rc-update add dbus
rc-update add udev

service seatd start
service dbus start
```

5. Auto-login on tty1
```
nano /etc/inittab
```

Find:
```
tty1::respawn:/sbin/getty 38400 tty1
```
Replace with:
```
tty1::respawn:/bin/login -f kiosk
```
and comment out the
```
tty2
tty3
tty4
tty5
tty6

::ctrlaltdel:/sbin/reboot
```
This prevents Ctrl+Alt+F2 escapes.

6. Start kiosk automatically
```
nano /home/kiosk/.profile
```
Content:
```
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_RUNTIME_DIR="$HOME/.run"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    exec cage -- chromium-browser \
      --kiosk \
      --user-data-dir=/tmp/profile \
      --no-first-run \
      --disable-translate \
      --disable-sync \
      --disable-features=TranslateUI \
      --disable-pinch \
      --overscroll-history-navigation=0 \
      --disable-session-crashed-bubble \
      https://www.google.com
fi
```

7. user group
```
adduser kiosk seat
adduser kiosk video
adduser kiosk input
adduser kiosk audio
```

10. Ephemeral browser profile (important)

Make browser profile RAM-only.
```
mkdir /tmp/profile
chown kiosk:kiosk /tmp/profile
```

11. Optional read-only root
For stronger appliance behavior:
```
apk add overlayroot
```
Or mount selected dirs as tmpfs.

```
nano /etc/fstab
```
Add:
```
tmpfs /tmp tmpfs defaults,noatime,size=512M 0 0
tmpfs /var/tmp tmpfs defaults,noatime,size=128M 0 0
```

12. Restrict networking (optional whitelist)

Only allow one domain:
```
iptables -P OUTPUT DROP
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```
- Also these rules vanish on reboot — use `iptables-save > /etc/iptables/rules.v4` or the `iptables-openrc` package on Alpine.

14. Lock shell further
Disable user shell access:
```
passwd -l root
usermod -s /sbin/nologin kiosk
```
Careful: only do this after confirming remote/admin access.

