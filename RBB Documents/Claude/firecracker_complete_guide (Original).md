# Complete Setup Guide: Firecracker + Browser + GUI Display

**Goal:** Run Chromium/Firefox inside Firecracker microVM with GUI output via VNC

**Time Required:** 2-3 hours (first time)

---

## Prerequisites

- **OS:** Ubuntu 22.04 LTS (bare metal or VM with nested virtualization)
- **CPU:** Intel with VT-x or AMD with AMD-V enabled
- **RAM:** Minimum 8GB
- **Disk:** 20GB free space
- **User:** sudo privileges

---

## Step 1: Verify KVM Support

```bash
# Check if KVM is available
lsmod | grep kvm

# Should see either:
# kvm_intel  (for Intel CPUs)
# kvm_amd    (for AMD CPUs)

# If not loaded, load it:
sudo modprobe kvm
sudo modprobe kvm_intel  # OR: sudo modprobe kvm_amd

# Verify /dev/kvm exists
ls -l /dev/kvm
# Should show: crw-rw---- 1 root kvm

# Add your user to kvm group
sudo usermod -a -G kvm $USER

# IMPORTANT: Logout and login again for group to take effect
```

---

## Step 2: Install Firecracker

```bash
# Download latest Firecracker release
FIRECRACKER_VERSION="v1.7.0"
wget https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-x86_64.tgz

# Extract
tar -xzf firecracker-${FIRECRACKER_VERSION}-x86_64.tgz

# Move binaries to /usr/local/bin
sudo mv release-${FIRECRACKER_VERSION}-x86_64/firecracker-${FIRECRACKER_VERSION}-x86_64 /usr/local/bin/firecracker
sudo mv release-${FIRECRACKER_VERSION}-x86_64/jailer-${FIRECRACKER_VERSION}-x86_64 /usr/local/bin/jailer

# Make executable
sudo chmod +x /usr/local/bin/firecracker
sudo chmod +x /usr/local/bin/jailer

# Verify installation
firecracker --version
# Should show: Firecracker v1.7.0

# Cleanup
rm -rf release-${FIRECRACKER_VERSION}-x86_64 firecracker-${FIRECRACKER_VERSION}-x86_64.tgz
```

---

## Step 3: Create Project Directory Structure

```bash
# Create working directory
mkdir -p ~/firecracker-browser
cd ~/firecracker-browser

# Create subdirectories
mkdir -p {kernel,rootfs,config,logs,scripts}

# Directory structure:
# ~/firecracker-browser/
# ├── kernel/        # Linux kernel image
# ├── rootfs/        # Root filesystem image
# ├── config/        # Firecracker configuration files
# ├── logs/          # Log files
# └── scripts/       # Helper scripts
```

---

## Step 4: Download Linux Kernel

```bash
cd ~/firecracker-browser/kernel

# Download pre-built kernel from Firecracker team
wget https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.7/x86_64/vmlinux-5.10.204

# Rename for simplicity
mv vmlinux-5.10.204 vmlinux

# Verify it's there
ls -lh vmlinux
# Should show file around 15-20MB
```

---

## Step 5: Build Root Filesystem with Browser

### Option A: Build from Alpine Linux (Recommended - Smaller)

```bash
cd ~/firecracker-browser/rootfs

# Install dependencies for building rootfs
sudo apt-get update
sudo apt-get install -y debootstrap e2fsprogs

# Create empty disk image (2GB)
dd if=/dev/zero of=rootfs.ext4 bs=1M count=2048

# Format as ext4
mkfs.ext4 rootfs.ext4

# Mount it
sudo mkdir -p /mnt/my-rootfs
sudo mount rootfs.ext4 /mnt/my-rootfs

# Install Alpine Linux base system using debootstrap alternative
# First, download Alpine minirootfs
wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz

# Extract to mounted filesystem
sudo tar -xzf alpine-minirootfs-3.19.0-x86_64.tar.gz -C /mnt/my-rootfs

# Chroot into the filesystem to install packages
sudo chroot /mnt/my-rootfs /bin/sh << 'EOF'
# Setup Alpine repositories
cat > /etc/apk/repositories << 'REPOS'
https://dl-cdn.alpinelinux.org/alpine/v3.19/main
https://dl-cdn.alpinelinux.org/alpine/v3.19/community
REPOS

# Update package index
apk update

# Install essential packages
apk add openrc util-linux

# Install networking
apk add iproute2 iptables

# Install display server and VNC
apk add xvfb x11vnc xfce4 dbus

# Install Chromium browser
apk add chromium

# Install supervisor for process management
apk add supervisor

# Enable necessary services
rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot
rc-update add networking boot

# Create supervisor config for browser session
mkdir -p /etc/supervisor/conf.d
cat > /etc/supervisor/conf.d/browser.ini << 'SUPER'
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log

[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 1920x1080x24
autorestart=true
stdout_logfile=/var/log/xvfb.log
stderr_logfile=/var/log/xvfb_err.log

[program:xfce4]
command=/usr/bin/startxfce4
environment=DISPLAY=":0"
autorestart=true
stdout_logfile=/var/log/xfce4.log
stderr_logfile=/var/log/xfce4_err.log

[program:x11vnc]
command=/usr/bin/x11vnc -display :0 -forever -shared -rfbport 5900 -nopw
autorestart=true
stdout_logfile=/var/log/x11vnc.log
stderr_logfile=/var/log/x11vnc_err.log
SUPER

# Create autostart script for Chromium
mkdir -p /root/.config/autostart
cat > /root/.config/autostart/chromium.desktop << 'CHROME'
[Desktop Entry]
Type=Application
Exec=chromium-browser --no-sandbox --disable-dev-shm-usage --start-maximized
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Chromium Browser
CHROME

# Set root password (for VNC auth if needed later)
echo "root:firecracker" | chpasswd

# Create init script to start supervisor
cat > /etc/init.d/browser-isolation << 'INIT'
#!/sbin/openrc-run

depend() {
    need networking
}

start() {
    /usr/bin/supervisord -c /etc/supervisor/conf.d/browser.ini
}
INIT

chmod +x /etc/init.d/browser-isolation
rc-update add browser-isolation default

EOF

# Unmount
sudo umount /mnt/my-rootfs

# Cleanup
rm alpine-minirootfs-3.19.0-x86_64.tar.gz

echo "✅ Root filesystem created: rootfs.ext4"
```

### Option B: Quick Ubuntu-based Build (Easier but Larger)

```bash
cd ~/firecracker-browser/rootfs

# Create 3GB disk image (Ubuntu needs more space)
dd if=/dev/zero of=rootfs.ext4 bs=1M count=3072
mkfs.ext4 rootfs.ext4

# Mount
sudo mkdir -p /mnt/my-rootfs
sudo mount rootfs.ext4 /mnt/my-rootfs

# Install Ubuntu base with debootstrap
sudo debootstrap --arch=amd64 jammy /mnt/my-rootfs http://archive.ubuntu.com/ubuntu/

# Chroot and install packages
sudo chroot /mnt/my-rootfs /bin/bash << 'EOF'
# Update
apt-get update

# Install minimal system
apt-get install -y systemd systemd-sysv

# Install networking
apt-get install -y iproute2 iputils-ping net-tools

# Install X server and VNC
apt-get install -y xvfb x11vnc xfce4 xfce4-terminal

# Install Chromium
apt-get install -y chromium-browser

# Install supervisor
apt-get install -y supervisor

# Create supervisor config
cat > /etc/supervisor/conf.d/browser.conf << 'SUPER'
[supervisord]
nodaemon=true

[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 1920x1080x24
autorestart=true

[program:xfce4]
command=/usr/bin/startxfce4
environment=DISPLAY=":0"
autorestart=true

[program:x11vnc]
command=/usr/bin/x11vnc -display :0 -forever -shared -nopw
autorestart=true
SUPER

# Auto-start Chromium
mkdir -p /root/.config/autostart
cat > /root/.config/autostart/chromium.desktop << 'CHROME'
[Desktop Entry]
Type=Application
Exec=chromium-browser --no-sandbox
Name=Chromium
CHROME

# Create systemd service for supervisor
cat > /etc/systemd/system/browser-isolation.service << 'SERVICE'
[Unit]
Description=Browser Isolation Session
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
ExecStop=/usr/bin/supervisorctl shutdown
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

# Enable the service
systemctl enable browser-isolation.service

# Set root password
echo "root:firecracker" | chpasswd

EOF

# Unmount
sudo umount /mnt/my-rootfs

echo "✅ Ubuntu root filesystem created: rootfs.ext4"
```

---

## Step 6: Create Firecracker Configuration File

```bash
cd ~/firecracker-browser/config

# Create VM configuration
cat > firecracker-config.json << 'CONFIG'
{
  "boot-source": {
    "kernel_image_path": "/home/YOUR_USERNAME/firecracker-browser/kernel/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "/home/YOUR_USERNAME/firecracker-browser/rootfs/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024,
    "ht_enabled": false
  },
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "AA:FC:00:00:00:01",
      "host_dev_name": "tap0"
    }
  ]
}
CONFIG

# IMPORTANT: Replace YOUR_USERNAME with your actual username
sed -i "s/YOUR_USERNAME/$USER/g" firecracker-config.json

echo "✅ Configuration created: firecracker-config.json"
```

---

## Step 7: Create Network TAP Device

```bash
# Create script to setup TAP interface
cat > ~/firecracker-browser/scripts/setup-network.sh << 'NETSCRIPT'
#!/bin/bash

# Create TAP device
sudo ip tuntap add tap0 mode tap
sudo ip addr add 172.16.0.1/24 dev tap0
sudo ip link set tap0 up

# Enable IP forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Setup NAT for internet access
sudo iptables -t nat -A POSTROUTING -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tap0 -o $(ip route | grep default | awk '{print $5}') -j ACCEPT

echo "✅ Network configured: tap0 at 172.16.0.1/24"
NETSCRIPT

chmod +x ~/firecracker-browser/scripts/setup-network.sh

# Run network setup
~/firecracker-browser/scripts/setup-network.sh
```

---

## Step 8: Create Launch Script

```bash
cat > ~/firecracker-browser/scripts/launch-browser.sh << 'LAUNCH'
#!/bin/bash

WORKDIR="$HOME/firecracker-browser"
SOCKET_PATH="/tmp/firecracker.socket"

# Remove old socket if exists
rm -f $SOCKET_PATH

# Setup network (if not already done)
if ! ip link show tap0 > /dev/null 2>&1; then
    $WORKDIR/scripts/setup-network.sh
fi

# Start Firecracker in background
echo "🚀 Starting Firecracker microVM..."
firecracker --api-sock $SOCKET_PATH --config-file $WORKDIR/config/firecracker-config.json &
FIRECRACKER_PID=$!

# Wait for VM to boot (adjust time as needed)
echo "⏳ Waiting for VM to boot..."
sleep 10

# Wait for VNC server to be ready
echo "⏳ Waiting for VNC server..."
sleep 5

# Find VNC port (forwarded from guest port 5900)
# Since Firecracker doesn't do port forwarding by default,
# we need to access via serial console or setup port forwarding manually

echo "✅ Firecracker VM is running!"
echo "📺 Connect VNC to: 172.16.0.2:5900"
echo "   (Guest IP should be 172.16.0.2 if DHCP/static config works)"
echo ""
echo "To connect:"
echo "  vncviewer 172.16.0.2:5900"
echo ""
echo "To stop the VM:"
echo "  kill $FIRECRACKER_PID"
echo "  rm -f $SOCKET_PATH"

# Keep script running
wait $FIRECRACKER_PID
LAUNCH

chmod +x ~/firecracker-browser/scripts/launch-browser.sh
```

---

## Step 9: Configure Guest Networking (Inside VM)

**IMPORTANT:** The guest VM needs network configuration. We need to add this to the rootfs:

```bash
# Mount rootfs again to add network config
sudo mount ~/firecracker-browser/rootfs/rootfs.ext4 /mnt/my-rootfs

# For Alpine Linux:
sudo chroot /mnt/my-rootfs /bin/sh << 'EOF'
cat > /etc/network/interfaces << 'NETCONF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 172.16.0.2
    netmask 255.255.255.0
    gateway 172.16.0.1
NETCONF

echo "nameserver 8.8.8.8" > /etc/resolv.conf
EOF

# OR for Ubuntu:
sudo chroot /mnt/my-rootfs /bin/bash << 'EOF'
cat > /etc/netplan/01-netcfg.yaml << 'NETCONF'
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 172.16.0.2/24
      gateway4: 172.16.0.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
NETCONF
EOF

# Unmount
sudo umount /mnt/my-rootfs

echo "✅ Guest networking configured"
```

---

## Step 10: Launch and Connect

```bash
# Install VNC viewer if not already installed
sudo apt-get install -y tigervnc-viewer

# Launch the VM
cd ~/firecracker-browser
./scripts/launch-browser.sh

# In another terminal, wait ~15 seconds, then connect via VNC:
vncviewer 172.16.0.2:5900

# You should see XFCE desktop with Chromium browser!
```

---

## Step 11: Testing Commands

```bash
# Check if Firecracker is running
ps aux | grep firecracker

# Check network
ip addr show tap0
ping -c 3 172.16.0.2

# Check if VNC port is accessible
nc -zv 172.16.0.2 5900

# View Firecracker logs (if any)
# Add logging to config:
# "logger": {
#   "log_path": "/home/user/firecracker-browser/logs/firecracker.log",
#   "level": "Debug"
# }
```

---

## Step 12: Create Stop Script

```bash
cat > ~/firecracker-browser/scripts/stop-browser.sh << 'STOP'
#!/bin/bash

# Kill Firecracker process
pkill -f firecracker

# Remove socket
rm -f /tmp/firecracker.socket

# Optionally remove TAP device
# sudo ip link delete tap0

echo "✅ Firecracker VM stopped"
STOP

chmod +x ~/firecracker-browser/scripts/stop-browser.sh
```

---

## Troubleshooting

### Problem: "Failed to open /dev/kvm"
```bash
# Check KVM permissions
ls -l /dev/kvm
# Should show group 'kvm'

# Add user to kvm group
sudo usermod -a -G kvm $USER

# Logout and login again
```

### Problem: "Cannot create TAP device"
```bash
# Load TUN/TAP module
sudo modprobe tun

# Check if loaded
lsmod | grep tun
```

### Problem: "Cannot connect to VNC"
```bash
# Check guest networking
# You may need to login via serial console first:
# Add to firecracker config:
# "console": {
#   "mode": "Stdio"
# }

# Then access via Firecracker API to configure network
```

### Problem: "Guest has no network"
```bash
# Verify TAP device on host
ip addr show tap0

# Check iptables rules
sudo iptables -t nat -L -n -v

# Test from host to guest
ping 172.16.0.2
```

---

## Performance Testing

```bash
# Measure boot time
time ./scripts/launch-browser.sh

# Monitor resource usage
htop  # or top

# Check Firecracker metrics
# Access API socket to get metrics
curl --unix-socket /tmp/firecracker.socket \
  http://localhost/metrics
```

---

## Summary of Files Created

```
~/firecracker-browser/
├── kernel/
│   └── vmlinux                       # Linux kernel
├── rootfs/
│   └── rootfs.ext4                   # Root filesystem with browser
├── config/
│   └── firecracker-config.json       # VM configuration
├── scripts/
│   ├── setup-network.sh              # Network setup
│   ├── launch-browser.sh             # Start VM
│   └── stop-browser.sh               # Stop VM
└── logs/
    └── (log files will appear here)
```

---

## Next Steps

1. ✅ Test basic browser functionality
2. Add file monitoring daemon to guest
3. Implement file transfer mechanism
4. Add threat detection scripts
5. Create automated screenshots for report

---

## For Your Report

**Screenshots to capture:**
- Terminal showing Firecracker launch
- VNC viewer connected to guest
- Chromium browser running inside VM
- `ps aux | grep firecracker` output
- Network configuration (`ip addr show`)

**Metrics to record:**
- Boot time (from launch to VNC connection)
- Memory usage (`free -h` on host)
- CPU usage during browsing

**Configuration files to include:**
- `firecracker-config.json`
- Guest network configuration
- Supervisor configuration

---

**Total Time: 2-3 hours for complete setup**
**Difficulty: ⭐⭐⭐⭐ (Advanced)**