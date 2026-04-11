# QEMU Browser VM with GUI (Corrected & Production-Ready Guide)

## 🎯 Goal
Run a Chromium browser inside a QEMU virtual machine **with full GUI support, keyboard, and mouse interaction**.

> ⚠️ Important Design Decision:
We DO NOT use `microvm` machine type because it is **not suitable for GUI workloads**.
Instead, we use **Q35 machine type**, which supports GPU, input devices, and desktop environments.

---

## ✅ Architecture Overview

- Machine type: `q35`
- Display: GTK (native window)
- GPU: virtio-vga
- Input: USB tablet (mouse) + keyboard
- Networking: user-mode (no bridge needed)
- OS: Ubuntu Desktop (ISO install)

---

## Part 1: System Preparation

### Install dependencies

```bash
sudo apt update
sudo apt install -y \
  qemu-system-x86 \
  qemu-utils \
  ovmf \
  wget
```

### Verify KVM

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
```

---

## Part 2: Create Disk Image

```bash
mkdir -p ~/qemu-browser-GPT-Me
cd ~/qemu-browser-GPT-Me

qemu-img create -f qcow2 ubuntu.img 30G
```

---

## Part 3: Download OS ISO

```bash
LATEST=$(curl -s https://releases.ubuntu.com/22.04/ | grep -oP 'ubuntu-22\\.04\\.[0-9]+-desktop-amd64\\.iso' | sort -V | tail -1)

wget https://releases.ubuntu.com/22.04/$LATEST
```

---

## Part 4: First Boot (Installation)

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 4G \
  \
  -drive file=ubuntu.img,format=qcow2,if=virtio \
  -cdrom ubuntu-24.04.4-desktop-amd64.iso \
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

### DEBUG
# For smoother UX (especially browser scrolling) add this
-device virtio-input-host-pci 
# instead of 
-device usb-tablet

### Install Ubuntu normally via GUI

- Choose minimal install (recommended)
- Create user: `browser`

---

## Part 5: Normal Boot Script

Create `run.sh`:

```bash
#!/bin/bash

qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 4G \
  \
  -drive file=ubuntu.img,format=qcow2,if=virtio \
  \
  -device virtio-vga \
  -display gtk,gl=on \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
```

```bash
chmod +x run.sh
./run.sh
```

---

## Part 6: Inside VM Setup

### Install browser

```bash
sudo apt update
sudo apt install -y chromium-browser
```

### Optional: Auto login

```bash
sudo mkdir -p /etc/lightdm/lightdm.conf.d/

sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=browser
autologin-user-timeout=0
EOF
```

---

### SSH Access (optional)

```bash
ssh browser@localhost -p 2222
```

---

## Part 7: Troubleshooting

### No display

```bash
-display gtk
```

### Slow graphics

```bash
-display gtk,gl=on
```

### Mouse issues

Ensure:

```bash
-device usb-tablet
```

---

## ✅ Final Result

You now have:

- Fully interactive GUI VM
- Browser running inside VM
- Mouse + keyboard input working
- Isolated environment

---

## 🚀 Optional Improvements

- Use SPICE for better performance
- Enable shared folders (virtio-fs)
- Add snapshots for quick reset

