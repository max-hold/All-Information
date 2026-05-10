# Update and install minimal GUI stack
```
apk update
apk add nano
cat /etc/alpine-release
```
# change the repos
```
nano /etc/apk/repositories
```
# add
```
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
```
# Add User to Groups
```
adduser max video
adduser max input
adduser max audio
```

# Install Xorg + XFCE + LightDM
```
setup-xorg-base

apk add xfce4 xfce4-terminal xfce4-screensaver \
lightdm lightdm-gtk-greeter \
dbus elogind polkit-elogind \
adwaita-icon-theme firefox
```

# Enable required services (OpenRC way)
```
rc-update add dbus
rc-update add elogind
rc-update add lightdm

rc-service dbus start
rc-service elogind start
rc-service lightdm start
```

# Enable auto-login (important for kiosk)
```
nano /etc/lightdm/lightdm.conf
```
- Find and set:
```
[Seat:*]
autologin-user=max
autologin-session=xfce
```

# Disable screen blanking / power saving
```
nano /home/max/.xprofile
```

- Add:
```
xset -dpms
xset s off
xset s noblank

# want to test this !!!!
setxkbmap -option
xmodmap -e "keycode 133 = NoSymbol"   # Super key
xmodmap -e "keycode 64 = NoSymbol"    # Alt
xmodmap -e "keycode 37 = NoSymbol"    # Ctrl
```

- Fix permissions:
```
chown max:max /home/max/.xprofile
chmod +x /home/max/.xprofile
```

# Auto-start Firefox in kiosk mode
```
mkdir -p /home/max/.config/autostart
nano /home/max/.config/autostart/firefox.desktop
```
- Paste:
```
[Desktop Entry]
Type=Application
Name=Firefox Kiosk
Exec=sh -c "while true; do firefox --kiosk https://www.google.com/; sleep 1; done"
X-GNOME-Autostart-enabled=true
```
- Fix permissions:
```
chown -R max:max /home/max/.config
```

# Optional: Hide XFCE UI elements (more kiosk-like)
```
rm -rf /home/max/.config/xfce4/panel
xfconf-query -c xfwm4 -p /general/use_compositing -s false  # (You may need to run that once inside the session.)
```

# Reboot
```
reboot
```
