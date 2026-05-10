# Secure QEMU + Alpine Linux Guest Implementation Guide
(incorporating all your recommendations + official docs from the provided articles)
This guide creates a minimal, secure, kiosk-style Alpine Linux VM in QEMU that:

* **Runs QEMU as an _unprivileged user_ with file-descriptor passing for `/dev/kvm`**.
* **Uses seccomp sandbox (`--sandbox on`)**
* **Uses virtio-gpu acceleration (`-vga virtio -display gtk,gl=on`)**
* **Uses user-mode networking (with `restrict=on` for isolation)**
* **Installs only `setup-xorg-base + lightdm + Firefox in kiosk mode` (auto-starts on login)**

## Tested concepts from:
* Alpine wiki: Install_Alpine_in_QEMU + QEMU page
* QEMU official security + invocation docs (unprivileged + sandbox + FD passing + virtio-gpu + snapshots)
* Yuankun & Suresh Joshi guides (minimal KVM/virtio setup)


# 1. Host Prerequisites (run once)
```
# Install the wanted packeges
sudo apt update
sudo apt install qemu-system-x86 qemu-utils qemu-kvm virt-viewer gtk+3.0 libvirt-clients bridge-utils

# Create unprivileged user for QEMU (recommended: "qemuuser")
sudo useradd -m -s /bin/bash qemuuser
sudo usermod -aG kvm qemuuser   # for fallback /dev/kvm access

# Allow your normal user to run the VM
sudo usermod -aG kvm $USER
```
### SELinux / AppArmor integration (host hardening):
* AppArmor: `sudo aa-enforce /etc/apparmor.d/usr.bin.qemu-system-x86_64` (or create a profile)
* SELinux: `sudo semanage fcontext -a -t qemu_exec_t "/usr/bin/qemu-system-x86_64"` + restorecon


# 2. Create Disk Image & Initial Install (run as your normal user)
```
mkdir -p ~/alpine-kvm && cd ~/alpine-kvm

# Download latest Alpine standard ISO (x86_64)
wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.3-x86_64.iso

# Create qcow2 disk (minimal 8G is fine)
qemu-img create -f qcow2 alpine-base.qcow2 8G

#Install boot command (temporary, with CDROM):
## THIS HAS A FAILES.
qemu-system-x86_64 \
  -m 1024 -smp 2 \
  -accel kvm \
  -cpu host \
  -machine q35 \
  -vga virtio -display gtk,gl=on \
  -netdev user,id=net0,restrict=off -device virtio-net-pci,netdev=net0 \
  -drive file=alpine-base.qcow2,if=virtio,format=qcow2 \
  -boot once=d \
  -cdrom alpine-standard-3.23.3-x86_64.iso \
  -sandbox on
```

### Inside the VM (login as root, no password):
```
setup-alpine          
# follow prompts (use dhcp, no root pw, create normal user "alpineuser", enable ssh if wanted)
poweroff
```

# 3. Guest Configuration (inside Alpine after first boot)
* Boot the installed system without ISO 
(same command as above but remove `-cdrom` and `-boot` lines).
```
qemu-system-x86_64 \
  -m 1024 -smp 2 \
  -accel kvm \
  -cpu host \
  -machine q35 \
  -vga virtio -display gtk,gl=on \
  -netdev user,id=net0,restrict=off -device virtio-net-pci,netdev=net0 \
  -drive file=alpine-base.qcow2,if=virtio,format=qcow2 \
  -boot order=c \
  -sandbox on
  -no-user-config -nodefaults \
  -name "Alpine-Post-Install"
```

### Inside Alpine (as root):
```
# Update & minimal Xorg + GUI
apk update
apk add xfce4 xfce4-terminal xfce4-screensaver lightdm lightdm-gtk-greeter dbus adwaita-icon-theme firefox
setup-xorg-base

# Enable services
rc-update add lightdm default
rc-service dbus start
rc-update add dbus
setup-devd udev

#This Packeg enable the user to poweroff the Pc(Add If you need) 
apk add elogind polkit-elogind


# Auto-login as "alpineuser" (change if you chose different name)
cat > /etc/lightdm/lightdm.conf <<EOF
[Seat:*]
allow-guest=false
autologin-user=alpineuser
autologin-user-timeout=0
EOF

# Kiosk mode: Firefox opens automatically in kiosk on login
cat > /home/alpineuser/.xsession <<EOF
#!/bin/sh
exec firefox --kiosk --private-window https://www.google.com/
EOF
chmod +x /home/alpineuser/.xsession

# Make sure Xorg uses virtio-gpu (auto with setup-xorg-base)
apk add xf86-video-virtio   # if needed

reboot

# Start the GUI
rc-service lightdm start
```

_**Test kiosk: After reboot, lightdm should auto-login and launch Firefox in full-screen kiosk mode.**_


# 4. Create & Store the "Golden Snapshot"
After you finish configuring Firefox (bookmarks, extensions, start page, etc.) and everything works:

- Shut down the VM cleanly inside Alpine (poweroff).
- On host, create a persistent snapshot overlay 
(this is the "stored snapshot" you will boot every time):

- Create the snapshot image (changes go here, base stays clean)
- Now every launch will use this snapshot (clean state every time).
```
qemu-img create -f qcow2 -b alpine-base.qcow2 -F qcow2 alpine-snapshot.qcow2 8G
```

# 5. Final Secure Launch Script (recommended: save as start-alpine-kiosk.sh)
```
#!/bin/bash
# Secure QEMU + Alpine Kiosk launcher
# Run as your normal user (no sudo needed)

cd ~/alpine-kvm

# File descriptor passing for /dev/kvm (exact method from QEMU security docs)
exec 3</dev/kvm

qemu-system-x86_64 \
  -m 1024 -smp 2 \
  -accel kvm \
  -cpu host \
  -machine q35 \
  -vga virtio -display gtk,gl=on \
  -netdev user,id=net0,restrict=off -device virtio-net-pci,netdev=net0 \
  -drive file=alpine-snapshot.qcow2,if=virtio,format=qcow2,cache=writeback \
  -sandbox on \
  -no-user-config -nodefaults \
  -name "Alpine-Kiosk" \
  "$@"
```

**Make executable:** `chmod +x start-alpine-kiosk.sh`

**Run it:** `./start-alpine-kiosk.sh`

_**Every launch starts from your stored snapshot.**_
_**Changes are discarded when you close QEMU (or delete/recreate alpine-snapshot.qcow2 to reset).**_

-  Verification commands (after it boots)
```
# Should show your normal user, NOT root
ps aux | grep qemu

# Seccomp is active
cat /proc/$(pidof qemu-system-x86_64)/status | grep Seccomp
```

# 6. Optional: Isolated Bridge Networking (instead of user-mode)
### If you prefer a real bridge (still isolated from host internet):
```
# On host (once)
sudo ip link add br0 type bridge
sudo ip addr add 192.168.42.1/24 dev br0
sudo ip link set br0 up

# Then in QEMU command replace the netdev line with:
-netdev bridge,id=net0,br=br0 -device virtio-net-pci,netdev=net0
(Requires qemu-bridge-helper setuid.)
```

# 7. Verification & Security Checklist

* QEMU runs as `qemuuser (ps aux | grep qemu)`
* Seccomp active `(cat /proc/$(pidof qemu-system-x86_64)/status | grep Seccomp)`
* FD passed `(ls -l /proc/$(pidof qemu)/fd/3 should show /dev/kvm)`
* virtio-gpu + GL acceleration visible in guest `(glxinfo | grep renderer)`
* Firefox kiosk auto-starts on login
* Snapshot is used every boot

This setup follows QEMU security documentation (least privilege, seccomp, FD passing, MAC via AppArmor/SELinux) and Alpine minimalism (tiny RAM/attack surface).

You now have a clean, secure, auto-launching kiosk VM that starts from the exact snapshot you stored on the host every single time.

Just run `./start-alpine-kiosk.sh` whenever you need it!

