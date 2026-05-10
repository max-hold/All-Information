# Add User to Groups
```
adduser browser-vm video
adduser browser-vm input
adduser browser-vm audio
```

# Install Xorg + XFCE + LightDM
```
setup-xorg-base

apk add xfce4 xfce4-terminal xfce4-screensaver \ 
lightdm lightdm-gtk-greeter \
dbus elogind polkit-elogind \
adwaita-icon-theme firefox

# If want 'mesa-dri-virtio' use this packegs 'mesa mesa-dri-gallium mesa-egl mesa-vulkan-virtio mesa-dri-swrast '
    # mesa-dri-gallium : used for virtio-gpu acceleration. 
    # mesa-vulkan-virtio: Provides Vulkan support for virtio-gpu
    # mesa-egl: Necessary for EGL support
    # mesa-dri-swrast: If 3D acceleration is not working

# Also if want 'xf86-video-virtio' use this packegs 'xf86-video-fbdev xf86-input-libinput xf86-video-vesa'
# 'xterm font-terminus openbox'
```

# Enable required services (OpenRC way)
```
rc-update add dbus
rc-update add elogind
rc-update add lightdm default

rc-service dbus start
rc-service elogind start
rc-service lightdm start
```

# Enable auto-login (important for kiosk)
```
sudo mkdir -p /etc/lightdm/lightdm.conf
nano /etc/lightdm/lightdm.conf
```
- Find and set:
```
[Seat:*]
allow-guest=false
autologin-user=browser-vm
autologin-session=xfce
autologin-user-timeout=0
# (If you set it to 10, it would wait 10 seconds and show a countdown.)
```

# Disable screen blanking / power saving
```
nano /home/browser-vm/.xprofile
```

- Add:
```
xset -dpms
xset s off
xset s noblank

setxkbmap -option
```

- Fix permissions:
```
chown browser-vm:browser-vm /home/browser-vm/.xprofile
chmod +x /home/browser-vm/.xprofile
```

# Auto-start Firefox in kiosk mode
```
mkdir -p /home/browser-vm/.config/autostart
nano /home/browser-vm/.config/autostart/firefox.desktop
```
- Paste:
```
[Desktop Entry]
Type=Application
Name=Firefox Kiosk
Exec=sh -c "while true; do firefox --kiosk https://www.google.com/; sleep 0; done"
X-GNOME-Autostart-enabled=true
```
- Fix permissions:
```
chown -R browser-vm:browser-vm /home/browser-vm/.config
```

# Optional: Hide XFCE UI elements (more kiosk-like)
```
rm -rf /home/browser-vm/.config/xfce4/panel
xfconf-query -c xfwm4 -p /general/use_compositing -s false  # (You may need to run that once inside the session.)
```

# Reboot
```
reboot
```
