# collects everything we need:
- CPU (Intel model, cores, threads)
- RAM
- Disk space
- GPU / graphics capabilities (critical for virglrenderer + 3D acceleration)
- KVM status
- Kernel version
- Wayland / desktop environment
- User permissions (kvm group, etc.)

nano ~/check_system.sh
```
#!/bin/bash
echo "=================================================================="
echo "   crosvm + KVM + virtio-gpu + Wayland DIAGNOSTIC SCRIPT"
echo "   (Ubuntu host with Intel KVM — read-only, safe)"
echo "=================================================================="

echo -e "\n[1] HOST OS & KERNEL"
echo "--------------------------------------------------"
cat /etc/os-release | grep -E 'PRETTY_NAME|VERSION'
uname -r
echo "Kernel build date: $(uname -v | cut -d' ' -f1-5)"

echo -e "\n[2] CPU (Intel KVM)"
echo "--------------------------------------------------"
lscpu | grep -E 'Architecture|Model name|CPU\(s\)|Thread|Socket|NUMA|Virtualization|CPU family|Model|Stepping'
echo "KVM modules loaded: $(lsmod | grep -E 'kvm_intel|kvm' | awk '{print $1}' | paste -sd ' ' -)"

echo -e "\n[3] MEMORY (RAM)"
echo "--------------------------------------------------"
free -h
echo "Swap: $(swapon --show | awk 'NR>1 {print $1 " " $3 " " $4}')"

echo -e "\n[4] STORAGE (Disk space for builds)"
echo "--------------------------------------------------"
df -h / /home
echo "Available in /tmp (for builds): $(df -h /tmp | awk 'NR==2 {print $4}')"

echo -e "\n[5] GPU / GRAPHICS (critical for virtio-gpu + virglrenderer)"
echo "--------------------------------------------------"
lspci | grep -E 'VGA|3D|Display'
echo -e "\nOpenGL / Mesa info (if available):"
if command -v glxinfo >/dev/null 2>&1; then
    glxinfo | grep -E 'OpenGL renderer|OpenGL version|OpenGL vendor'
else
    echo "   glxinfo not installed (optional: sudo apt install mesa-utils)"
fi
echo -e "\nMesa / virgl support packages installed:"
dpkg -l | grep -E 'mesa|virgl|libgl1-mesa' | awk '{print $2 " " $3}'

echo -e "\n[6] KVM & Virtualization Status"
echo "--------------------------------------------------"
kvm-ok 2>/dev/null || echo "kvm-ok not installed (optional: sudo apt install cpu-checker)"
ls -l /dev/kvm
echo "Current user in kvm group? $(groups | grep -o '\bkvm\b' || echo 'NO — we will fix this')"

echo -e "\n[7] WAYLAND / DESKTOP ENVIRONMENT (we need this for passthrough)"
echo "--------------------------------------------------"
echo "Display server: $XDG_SESSION_TYPE"
echo "Wayland socket: ${XDG_RUNTIME_DIR}/wayland-*"
echo "Compositor: $(ps -e | grep -E 'gnome-shell|plasma|kwin|sway|hyprland|weston' | awk '{print $4}' | head -1 || echo 'unknown')"

echo -e "\n[8] USER PERMISSIONS & GROUPS"
echo "--------------------------------------------------"
id
echo "Groups: $(groups)"

echo -e "\n[9] QUICK SUMMARY"
echo "--------------------------------------------------"
echo "✅ Run this script and paste the FULL output back to me."
echo "I will check if your Intel CPU + GPU is ready for:"
echo "   • crosvm with virtio-gpu 3D acceleration"
echo "   • Wayland passthrough (best smoothness)"
echo "   • Alpine + Firefox prototype"

echo "=================================================================="
echo "Script finished. Copy everything above this line."
echo "=================================================================="
```
chmod +x ~/check_system.sh
~/check_system.sh


PHASE 1: Build crosvm (with GPU support)
```
# 1. Update system and install build dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl build-essential pkg-config meson ninja-build cmake \
    libwayland-dev libepoxy-dev libdrm-dev libgbm-dev libxkbcommon-dev \
    libvirglrenderer-dev mesa-utils

# 2. Install latest Rust (stable)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup default stable

# 3. Clone crosvm and run official setup script
cd ~
git clone https://chromium.googlesource.com/crosvm/crosvm
cd crosvm
git submodule update --init
./tools/setup   # this installs any extra Ubuntu packages crosvm needs

# 4. Build crosvm with GPU/virglrenderer support (release build = faster)
cargo build --release --features "gpu"
```

```
ls -l target/release/crosvm
```


Phase 2: Official Alpine + Manual Setup (Simpler & More Reliable)
```
# 1. Go to our working folder
cd ~/crosvm-browser

# 2. Download the latest official Alpine virt ISO (3.23.4 as of April 2026)
wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-virt-3.23.4-x86_64.iso

# 3. Create a persistent 8 GB qcow2 disk (this is where Firefox and your changes will be saved)
qemu-img create -f qcow2 alpine-persistent.qcow2 8G
```


Installation command (use this ONLY the first time)
```
cd ~/crosvm-browser

qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -boot d \
  -cdrom alpine-virt-3.23.4-x86_64.iso \
  -drive file=alpine-persistent.qcow2,format=qcow2 \
  -vga virtio \
  -display gtk,gl=on \
  -net nic,model=virtio -net user
```

Normal boot command (this is what you will use forever after setup)
```
cd ~/crosvm-browser

qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -boot c \
  -drive file=alpine-persistent.qcow2,format=qcow2 \
  -vga virtio \
  -display gtk,gl=on \
  -net nic,model=virtio -net user
```


Inside the VM
```
# 1. Update package list
apk update

# 2. Install Firefox + GPU drivers + Xorg (this takes 2–4 minutes)
apk add firefox-esr mesa-dri-gallium mesa-va-gallium xorg-server xf86-video-vesa dbus eudev

# 3. Enable required services to start at boot
rc-update add dbus default
rc-update add udev default
rc-update add udev-trigger default
rc-update add udev-settle default
```


