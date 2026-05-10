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
