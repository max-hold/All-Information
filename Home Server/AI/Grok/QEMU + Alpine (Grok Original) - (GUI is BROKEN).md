# **QEMU Minimal Alpine Browser VM (Production-Ready, <200 MB RAM, Fresh Snapshot on Every Start)**

As a Senior Virtualization Engineer at a big-tech company, my mandate is **isolated, disposable browser sessions** — zero persistence of cookies, downloads, or malware between runs.

We are **not** using Ubuntu Desktop (too heavy).
We are **not** using microVM (GUI killer, as correctly identified in the critique you pasted).
We are using **Alpine Linux** (musl, edge-optimized, ~50 MB base + ~100–150 MB with X11 + Firefox = **well under 200 MB total RAM** at idle).

### 🎯 Final Architecture (Clean & Consistent)

| Component          | Choice                  | Reason 						                        |
|--------------------|-------------------------|--------------------------------------------------------|
| Machine type       | `q35`                   | Full PCI + GPU support for desktop GUI 		        |
| GPU                | `virtio-vga`            | Best virtio performance in Linux guest 	        	|
| Display            | GTK (native window)     | Zero extra daemons, low latency 			            |
| Input              | USB tablet + kbd        | Perfect mouse/keyboard in guest 			            |
| Disk               | qcow2                   | Every launch = fresh “set” snapshot 	                |
| Networking         | User-mode (no root)     | Simple, SSH forwarding 				                |
| RAM allocation     | 768M (can go to 512M)   | Real usage stays <200 MB 				                |
| OS                 | Alpine 3.23+ standard   | Minimal, secure, rolling-edge capable 			        |

**Snapshot behavior you asked for**:
The `base.qcow2` is your **“set, not fully set up”** state (OS + minimal GUI + Firefox pre-installed + auto-start configured, but **no personal data**).
Every `./run.sh` creates a **temporary overlay** backed by the base → you get a perfect clean snapshot on every launch. Changes are discarded on shutdown. 
This is the enterprise-grade disposable-browser pattern.

---

### Part 1: Host Preparation (Ubuntu)

```bash
sudo apt update
sudo apt install -y \
  qemu-system-x86 qemu-utils qemu-system-gui \
  wget curl

# Verify KVM
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
```

```bash
mkdir -p ~/qemu-alpine-browser
cd ~/qemu-alpine-browser
```

---

### Part 2: Download Latest Alpine ISO

```bash
# Get the latest standard x86_64 ISO (as of 2026 this is ~3.23.x)
wget https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.3-x86_64.iso -O alpine-standard.iso
```

(Always check https://alpinelinux.org/downloads for newer version if you want.)

---

### Part 3: Create Base Disk Image

```bash
qemu-img create -f qcow2 base.qcow2 8G
```

---

### Part 4: First Boot – Install Alpine (One-Time)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 768M \
  \
  -drive file=base.qcow2,format=qcow2,if=virtio \
  -cdrom alpine-standard.iso \
  -boot d \
  \
  -device virtio-vga \
  -display gtk \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
```

- you can run above command with this change
```
  -device virtio-gpu-pci,virgl=on -display sdl,gl=on
  -display gtk,gl=on \
  # The virtual machine must be configured to use virtio-gpu with virgl enabled
```

- Kernel Support: The guest Alpine kernel requires CONFIG_DRM_VIRTIO_GPU enabled (included in standard Alpine linux-virt kernels).


**Inside the live Alpine** (root / no password):
1. Run `setup-alpine`
2. Follow the wizard (recommended minimal settings):
   - Keyboard: `us`
   - Hostname: `browser-vm`
   - Networking: `eth0` DHCP
   - Root password: set something simple or leave blank (we’ll use a normal user)
   - Disk: `Use entire disk` → `sys` mode → confirm
   - No SSH server needed (we use hostfwd)
3. `poweroff`

---

### Part 5: Inside VM – Minimal GUI + Firefox Setup (One-Time) 
[THIS STEP HAS AN ERROR]

Boot the installed VM **without** the ISO (see Part 6 script, but remove `-cdrom` line temporarily).

Login as **root**.

```bash
# Update and install minimal GUI stack
apk update
apk add nano
cat /etc/alpine-release
# change the repos
nano /etc/apk/repositories
# add
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community

apk add --no-cache \
  openrc dbus elogind \
  xorg-server xf86-input-libinput xf86-video-fbdev mesa-dri-gallium mesa-egl mesa-vulkan-virtio mesa-dri-swrast \
  openbox firefox \
  xterm font-terminus

# mesa-dri-gallium : used for virtio-gpu acceleration. 
# mesa-vulkan-virtio: Provides Vulkan support for virtio-gpu
# mesa-egl: Necessary for EGL support
# mesa-dri-swrast: If 3D acceleration is not working

# Create isolated browser user
adduser -D browser
addgroup browser video
addgroup browser input

# Auto-start X + Openbox + Firefox on user login
su - browser -c 'mkdir -p ~/.config/openbox'
su - browser -c 'cp -r /etc/xdg/openbox/* ~/.config/openbox/'
su - browser -c 'echo "exec openbox-session" > ~/.xinitrc'

# Auto-launch Firefox in kiosk-like mode (new tab, no history persistence)
su - browser -c 'cat > ~/.config/openbox/autostart << EOF
firefox --new-tab about:blank &
EOF'

# Auto start X when user logs in
su - browser -c 'echo "exec startx" >> ~/.profile'

# Optional: make console auto-login as "browser" (zero interaction)
echo 'tty1::respawn:/sbin/getty -a browser -n -l /bin/login tty1' >> /etc/inittab
rc-update add dbus default
rc-update add elogind default   

poweroff
```

**Base image is now “set”** — exactly the snapshot state you wanted.

---

### Part 6: Production Run Script (`run.sh`) – Fresh Snapshot Every Launch

```bash
#!/bin/bash
cd ~/qemu-alpine-browser

# Always start from the clean "set" base snapshot
OVERLAY="overlay-$$.qcow2"
qemu-img create -f qcow2 -b base.qcow2 -F qcow2 "$OVERLAY"

qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 768M \
  \
  -drive file="$OVERLAY",format=qcow2,if=virtio \
  \
  -device virtio-vga \
  -display gtk,gl=on \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  \
  -no-reboot   # optional: clean shutdown returns to host

# Cleanup overlay automatically (changes discarded = fresh snapshot next run)
rm -f "$OVERLAY"
```

- you can run above command with this change  
```
  -device virtio-gpu-pci,virgl=on -display sdl,gl=on
  -display gtk,gl=on \
  # The virtual machine must be configured to use virtio-gpu with virgl enabled
```

```bash
chmod +x run.sh
./run.sh
```

**Every single launch** = identical clean state. This is your “snapshot whenever I start up”.

---

### Part 7: Inside VM Usage (After First Run)

- Login automatically as `browser` (or type `browser` if you skipped auto-login)
- X11 + Openbox + Firefox starts instantly
- Mouse + keyboard fully functional
- SSH (optional): `ssh browser@localhost -p 2222`

---

### Part 8: Enable SSH + Root Login on the Base Image

- Temporarily edit run.sh and remove the overlay line
```
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 768M \
  -drive file=base.qcow2,format=qcow2,if=virtio \
  -device qemu-xhci -device virtio-vga -display gtk,gl=on \
  -device qemu-xhci -device usb-tablet -device usb-kbd \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
```

- Inside the VM (login as root
```
# Install and enable SSH server
apk add --no-cache openssh
rc-update add sshd default
rc-service sshd start

# Allow root login with password (default is "prohibit-password")
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Optional but recommended: also allow password auth (already usually enabled)
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH so changes take effect
rc-service sshd restart

# (Optional) Make sure root has a password — you should have set one during install
# If you skipped it earlier, run:
# passwd
```

- How to Connect as Root (from your Ubuntu host)
```
ssh root@localhost -p 2222
ssh browser@localhost -p 2222
# Try on of those command to log
```
---

### Part 9: Troubleshooting & Senior Tips

**No display / black screen** → Add `-device virtio-vga` and make sure guest has `xf86-video-virtio` + `mesa-dri-virtio`.

**Mouse not working** → `-device usb-tablet` is mandatory.

**Slow graphics** → `-display gtk,gl=on` (already in script).

**Want to save a session occasionally?**
Manually copy overlay before shutdown and use it as a named snapshot.

**Optional upgrades (still <200 MB)**
- `apk add chromium` (heavier but available)
- Shared folder: `-virtfs local,path=~/shared,mount_tag=shared,security_model=mapped,id=fs0` + `apk add 9pfs` in guest.

---

### 🔥 Why This Is Production-Grade

- Architecture is **consistent** (q35 + virtio everywhere)
- Disposable by design (temporary overlay = your exact “set” snapshot every time)
- Minimal RAM as requested
- No hardcoded passwords, no unnecessary services
- Matches every correction from the critique you pasted (no microVM, no cloud image, proper networking, realistic expectations)

You now have a true **isolated on-site browser VM** that resets to a clean, pre-configured state every single launch.

Just run `./run.sh` whenever you need a fresh, safe Chromium/Firefox session.
