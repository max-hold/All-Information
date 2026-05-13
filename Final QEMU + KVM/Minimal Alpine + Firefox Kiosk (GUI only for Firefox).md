# Minimal Alpine Kiosk (Openbox + Firefox) – Complete & Fixed Guide

# run as root and add `Nano`
```
su -
apk update
apk add nano
```
# change the repos
```
cat /etc/alpine-release
nano /etc/apk/repositories
```
# add
```
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
```
# change the permission 
```
chmod 644 /etc/apk/repositories
chown root:root /etc/apk/repositories
```
# Install packages
```
apk add --no-cache \
    openbox dbus elogind polkit-elogind \
    firefox \
    unclutter-xfixes \
    ttf-dejavu ttf-liberation font-noto font-noto-cjk font-noto-extra ttf-freefont \
    fontconfig
```
# Install Xorg base
```
setup-xorg-base
```
# Enable services
```
rc-update add dbus
rc-update add elogind

rc-service dbus start
rc-service elogind start
```
# Create user
```
adduser max video
adduser max input
adduser max audio
```
# Switch to user
```
su - max
```
# Create Openbox config directory
```
mkdir -p /home/max/.config/openbox
chmod 700 /home/max/.config/openbox
```
# Create .xinitrc
```
nano /home/max/.xinitrc
```
# add
```
#!/bin/sh

# Disable screen blanking / DPMS
xset -dpms
xset s off
xset s noblank

# Hide mouse cursor after 1 second of idle
unclutter -idle 1 -root &

# Start Openbox (proper session management)
exec openbox-session

# Disable Ctrl+Alt+Backspace
setxkbmap -option terminate:ctrl_alt_bksp

# Disable X server hotkeys / grabs
setxkbmap -option srvrkeys:none

# Disable VT switching (Ctrl+Alt+F1-F12)
setxkbmap -option ""
```
# change the permission 
```
chmod +x /home/max/.xinitrc
chmod 700 /home/max/.xinitrc
chown max:max /home/max/.xinitrc
```
# Create Openbox autostart
```
cat > /home/max/.config/openbox/autostart <<EOF
#!/bin/sh

# Start Firefox in kiosk loop (change the URL/path to your content)
while true; do
    firefox --kiosk https://www.google.com/
    sleep 1
done
EOF

chmod +x /home/max/.config/openbox/autostart
chmod 700 /home/max/.config/openbox/autostart
chown max:max /home/max/.config/openbox/autostart
```
# Edit user profile
```
nano /home/max/.profile
```
# add
```
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi
```
# change the permission
```
chmod 600 /home/max/.profile
chown max:max /home/max/.profile
```
#  Edit inittab
```
su -

nano /etc/inittab
```
- Find this line:
`ttty1::respawn:/sbin/getty 38400 tty1`
- Replace with:
`tty1::respawn:/bin/login -f max`
- and comment the all tty lines

# change the permission
```
chmod 644 /etc/inittab
chown root:root /etc/inittab
```
# Create system startx hook
```
su -

cat > /etc/profile.d/startx.sh <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
```
# change the permission
```
chmod +x /etc/profile.d/startx.sh
chmod 755 /etc/profile.d/startx.sh
chown root:root /etc/profile.d/startx.sh
```

# Disable the Openbox right-click desktop menu
```
su - max

cat > /home/max/.config/openbox/rc.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <mouse>
    <context name="Root">
      <!-- Remove all mouse bindings on the desktop -->
    </context>
  </mouse>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>

    <!-- Disable Alt+Tab -->
    <keybind key="A-Tab">
      <action name="Execute">
        <command>true</command>
      </action>
    </keybind>

    <keybind key="A-S-Tab">
      <action name="Execute">
        <command>true</command>
      </action>
    </keybind>

    <!-- Disable Super / Windows keys -->
    <keybind key="W-L">
      <action name="Execute"><command>true</command></action>
    </keybind>
    <keybind key="W-R">
      <action name="Execute"><command>true</command></action>
    </keybind>

    <!-- Disable Alt+F4 -->
    <keybind key="A-F4">
      <action name="Execute"><command>true</command></action>
    </keybind>

    <!-- Disable Ctrl+Alt+Delete -->
    <keybind key="C-A-Delete">
      <action name="Execute"><command>true</command></action>
    </keybind>

    <!-- Disable all F1-F12 -->
    <keybind key="F1"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F2"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F3"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F4"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F5"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F6"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F7"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F8"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F9"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F10"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F11"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="F12"><action name="Execute"><command>true</command></action></keybind>
  </keyboard>
  </keyboard>
</openbox_config>
EOF

chmod 600 /home/max/.config/openbox/rc.xml
chown max:max /home/max/.config/openbox/rc.xml
```

- not sure this work because it didn't try.
- Mount the filesystem read-only where possible
```
su -

# In /etc/fstab, add ro flag to root if your setup allows it
# At minimum, make /home read-only except for Firefox's profile dir
chmod 644 /etc/fstab
chown root:root /etc/fstab
```

```
lbu commit -d
```

```
kill -HUP 1
```

```
reboot
```

- start it manualy 
```
su - max
startx
```

- Check logs if needed:
```
/home/max/.xsession-errors
/var/log/Xorg.0.log
```

