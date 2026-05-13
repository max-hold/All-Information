# QEMU/KVM + Alpine + Firefox_Kiosk - Complete Setup Guide

---

## Part 1: System Preparation
### Step 1.1: Verify KVM Support
```
# Check virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo
# Should return > 0

# Check KVM device
ls -l /dev/kvm

# Load KVM modules
sudo modprobe kvm
sudo modprobe kvm_intel  # OR: sudo modprobe kvm_amd

# Create unprivileged user for QEMU (recommended: "qemuuser")
sudo useradd -m -s /bin/bash qemuuser
sudo usermod -aG kvm qemuuser   # for fallback /dev/kvm access

# Add User to libvirt to Allow Access to VMs
sudo usermod -aG libvirt $USER
sudo usermod -aG libvirt-qemu $USER

# Add user to kvm group
sudo usermod -aG kvm $USER
sudo usermod -aG input $USER
sudo usermod -aG disk $USER
newgrp kvm
```

### Step 1.2: Install Host Dependency
```
# Update system
sudo apt update && sudo apt upgrade -y

# Install QEMU and dependencies
sudo apt install -y \
    qemu-system-x86 \
    qemu-utils \
    qemu-kvm \
    qemu-system-gui \
    libvirt-daemon-system \
    libvirt-clients \
    libvirt-daemon \
    bridge-utils \
    virt-manager \
    virtinst \
    ovmf \
    wget \
    curl \
    cloud-image-utils \
    genisoimage \
    python3 \
    python3-pip

# Verify QEMU version
qemu-system-x86_64 --version
# Should show: QEMU emulator version 6.2.0 or higher

# Verify that Libvirtd service is started
sudo systemctl status libvirtd.service
```

---

## Part 2: Create Guest OS Image
### Step 2.1: Download Alpine Image
```
mkdir -p ~/qemu-max-test
cd ~/qemu-max-test

# Get the latest standard x86_64 ISO
BASE_URL="https://dl-cdn.alpinelinux.org/alpine"

LATEST_VER=$(curl -s $BASE_URL/ \
  | grep -oP 'v[0-9]+\.[0-9]+' \
  | sort -V | tail -1)

LATEST_ISO=$(curl -s $BASE_URL/$LATEST_VER/releases/x86_64/ \
  | grep -oP 'alpine-standard-[0-9]+\.[0-9]+\.[0-9]+-x86_64\.iso' \
  | sort -V | tail -1)

wget $BASE_URL/$LATEST_VER/releases/x86_64/$LATEST_ISO -O alpine-standard.iso

# Create qcow2 disk (minimal 8G is fine)
qemu-img create -f qcow2 alpine-standard-base.qcow2 15G

```

---

## Part 3: First Boot – Install Alpine (One-Time)
### Step 3.1: Install boot command (temporary, with CDROM)  
```
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 2G \
  \
  -drive file=alpine-standard-base.qcow2,format=qcow2,if=virtio \
  -cdrom alpine-standard.iso \
  -boot d \
  \
  -device virtio-vga \
  -display gtk,gl=on \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,restrict=off,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
```
- you can run above command with this change to more secure
```
  -sandbox on \
```

- you can run above command with this change
```
  # The virtual machine must be configured to use virtio-gpu with virgl enabled
  -device virtio-gpu-pci,virgl=on -display sdl,gl=on \
  -display gtk,gl=on \
  # instead of
  -device virtio-vga \
  -display gtk \
```

- For smoother UX (especially browser scrolling)
```
# For smoother UX (especially browser scrolling) add this
-device virtio-input-host-pci \ 
# instead of 
-device usb-tablet \
```
- Kernel Support: The guest Alpine kernel requires CONFIG_DRM_VIRTIO_GPU enabled (included in standard Alpine linux-virt kernels).


**Inside the live Alpine** (root / no password):
1. Run `setup-alpine`
2. Follow the wizard (recommended minimal settings):
   - Keyboard: `us`
   - Hostname: `max`
   - Networking: `eth0` DHCP
   - Root password: set something simple or leave blank (we’ll use a normal user)
   - Disk: `Use entire disk` → `sys` mode → confirm
   - No SSH server needed (we use hostfwd)
3. `poweroff`

---

## Part 4: Snap Boot – After Install Alpine
### Step 4.1: Normal Boot Script
```
cat > run.sh <<EOF
#!/bin/bash

qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 2G \
  \
  -drive file=alpine-standard-base.qcow2,format=qcow2,if=virtio \
  -boot c \
  \
  -device virtio-vga \
  -display gtk,gl=on \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,restrict=off,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  \
  -sandbox on \
  -no-user-config -nodefaults \
  -name "Alpine-Post-Install"
EOF
```

```
chmod +x run.sh
./run.sh
```

---

## Part 5: Inside VM Setup 
[OR YOU CAN USE THE 'Minimal Alpine + Firefox Kiosk (GUI only for Firefox).md' FILE GUIDE FOR MORE SECURE UI]

---

## Part 6: Create & Store the "Golden Snapshot"
### Step 6.1: Create the snapshot image

After you finish configuring Firefox (bookmarks, extensions, start page, etc.) and everything works:

- Shut down the VM cleanly inside Alpine (poweroff).
- On host, create a persistent snapshot overlay 
(this is the "stored snapshot" you will boot every time):

- Create the snapshot image (changes go here, base stays clean)
- Now every launch will use this snapshot (clean state every time).
```
qemu-img create -f qcow2 -b alpine-standard-base.qcow2 -F qcow2 alpine-snapshot-golden.qcow2 8G
```

### Step 6.2: Final Launch Script with "Golden Snapshot" (recommended: save as start-alpine-kiosk.sh)
```
#!/bin/bash
# =============================================
# Secure Disposable Alpine Kiosk Launcher
# Always boots from clean golden snapshot
# Changes are discarded on every shutdown
# =============================================


cd ~/qemu-max-test || { echo "Error: Directory ~/alpine-kvm not found"; exit 1; }

# === 1. Create temporary overlay (fresh every run) ===
OVERLAY="temp-overlay-$$.qcow2"          # unique name using process ID
echo "Creating temporary overlay from golden snapshot..."
qemu-img create -f qcow2 -b alpine-snapshot-golden.qcow2 -F qcow2 "$OVERLAY" || exit 1

# === 2. File descriptor for /dev/kvm (required for sandbox) ===
exec 3</dev/kvm

# === 3. QEMU command (GUI fixed + your security settings) ===
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -cpu host \
  -smp 2 \
  -m 2G \
  \
  -drive file="$OVERLAY",format=qcow2,if=virtio,cache=writeback \
  -boot c \
  \
  -device virtio-vga \
  -display gtk,gl=on \
  \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  \
  -netdev user,id=net0,restrict=off,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0\
  \
  -sandbox on \
  -no-user-config \
  -nodefaults \
  -name "Alpine-Kiosk" \
  "$@"
# === 4. Cleanup: delete temporary overlay (changes are gone) ===
echo "🧹 Cleaning up temporary overlay..."
rm -f "$OVERLAY"

# If you ever want to update the golden state (add new packages, change Firefox config, etc.), just:
# Temporarily comment out the cleanup line (rm -f "$OVERLAY")
# Run the script and make your changes
# Shut down the VM
# Recreate the snapshot (see below)
# Uncomment the cleanup line again
```

```
chmod +x start-alpine-kiosk.sh
./start-alpine-kiosk.sh
```
