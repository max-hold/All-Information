# Cloud Hypervisor + GUI — Complete Setup Guide (Final Corrected)

## Goal

Run a **Firefox browser inside a Cloud Hypervisor microVM** with:

* GUI (XFCE)
* Mouse + keyboard input via VNC
* Stable networking
* Secure SSH access

---

## ⚠️ Key Design Notes (Important)

* Cloud Hypervisor is **not designed for GUI workloads**
* This setup is **for lab / isolation use**, not desktop replacement
* We use:

  * **Static networking (NO DHCP issues)**
  * **systemd-managed VNC (persistent + stable)**
  * **SSH key auth (no passwords)**

---

# Part 1: System Preparation

## 1.1 Verify Virtualization

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
```

```bash
sudo modprobe kvm
sudo modprobe kvm_intel   # OR kvm_amd
sudo usermod -aG kvm $USER
newgrp kvm
```

---

## 1.2 Install Dependencies

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  build-essential git curl wget \
  pkg-config libssl-dev \
  qemu-utils cloud-image-utils genisoimage \
  netcat-openbsd nbd-client \
  tigervnc-viewer remmina \
  python3 python3-pip
```

---

# Part 2: Install Cloud Hypervisor

```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

git clone https://github.com/cloud-hypervisor/cloud-hypervisor.git
cd cloud-hypervisor
cargo build --release

sudo cp target/release/cloud-hypervisor /usr/local/bin/
cloud-hypervisor --version

cd ~
mkdir -p ~/cloud-hypervisor-setup
cd ~/cloud-hypervisor-setup
```

---

# Part 3: Create VM Image

## 3.1 Download Image

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

cp jammy-server-cloudimg-amd64.img ubuntu.img
qemu-img resize ubuntu.img +10G
```

---

## 3.2 Extract Kernel + Initrd

```bash
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 ubuntu.img
sleep 2

sudo mkdir -p /mnt/guest
sudo mount /dev/nbd0p1 /mnt/guest

KERNEL=$(sudo ls /mnt/guest/boot/vmlinuz-* | sort -V | tail -1)
INITRD=$(sudo ls /mnt/guest/boot/initrd.img-* | sort -V | tail -1)

sudo cp "$KERNEL" ./vmlinuz
sudo cp "$INITRD" ./initrd.img
sudo chown $USER:$USER vmlinuz initrd.img

sudo umount /mnt/guest
sudo qemu-nbd --disconnect /dev/nbd0
```

---

# Part 4: Cloud-Init Configuration

## 4.1 Generate SSH Key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ch_vm -N ""
```

---

## 4.2 user-data

```bash
cat > user-data <<EOF
#cloud-config

hostname: browser-vm

users:
  - name: browser
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat ~/.ssh/ch_vm.pub)

packages:
  - xfce4
  - xfce4-goodies
  - tightvncserver
  - firefox
  - openssh-server

write_files:
  - path: /home/browser/.vnc/xstartup
    owner: browser:browser
    permissions: '0755'
    content: |
      #!/bin/bash
      startxfce4 &

  - path: /etc/systemd/system/vncserver@.service
    permissions: '0644'
    content: |
      [Unit]
      Description=VNC Server

      [Service]
      Type=forking
      User=browser
      ExecStart=/usr/bin/vncserver :1 -geometry 1280x800 -depth 24
      ExecStop=/usr/bin/vncserver -kill :1
      Restart=always

      [Install]
      WantedBy=multi-user.target

runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - su - browser -c "mkdir -p ~/.vnc && echo password | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd"
  - systemctl daemon-reexec
  - systemctl enable vncserver@1
  - systemctl start vncserver@1
EOF
```

---

## 4.3 meta-data

```bash
cat > meta-data <<EOF
instance-id: vm-01
local-hostname: browser-vm
EOF
```

---

## 4.4 FIXED Network Config (STATIC — NO DHCP ISSUE)

```bash
cat > network-config <<EOF
version: 2
ethernets:
  eth0:
    match:
      name: "en*"
    addresses:
      - 192.168.100.2/24
    gateway4: 192.168.100.1
    nameservers:
      addresses: [8.8.8.8,1.1.1.1]
EOF
```

---

## 4.5 Create Cloud Init ISO

```bash
cloud-localds -N network-config cloud-init.img user-data meta-data
```

---

# Part 5: Networking (TAP + NAT)

```bash
TAP=tap0
HOST_IP=192.168.100.1
SUBNET=192.168.100.0/24

sudo ip tuntap add $TAP mode tap user $USER || true
sudo ip addr add $HOST_IP/24 dev $TAP || true
sudo ip link set $TAP up

sudo sysctl -w net.ipv4.ip_forward=1

MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)

sudo iptables -t nat -A POSTROUTING -s $SUBNET -o $MAIN_IF -j MASQUERADE || true
sudo iptables -A FORWARD -i $TAP -j ACCEPT || true
sudo iptables -A FORWARD -o $TAP -j ACCEPT || true
```

---

# Part 6: Launch VM

```bash
cloud-hypervisor \
  --kernel ./vmlinuz \
  --initramfs ./initrd.img \
  --cmdline "console=hvc0 root=/dev/vda1 rw" \
  --cpus boot=2 \
  --memory size=2G \
  --disk path=ubuntu.img,cache=none,direct=on \
  --disk path=cloud-init.img,readonly=on \
  --net tap=tap0,mac=AA:BB:CC:DD:EE:FF \
  --console off \
  --serial null \
  --log-file ch.log
```

---

# Part 7: Connect to VM

## 7.1 Wait for VM

```bash
until nc -z 192.168.100.2 22; do sleep 2; done
until nc -z 192.168.100.2 5901; do sleep 2; done
```

---

## 7.2 VNC (GUI)

```bash
vncviewer 192.168.100.2:5901
```

* Password: `password`
* You will see XFCE desktop
* Open Firefox normally

---

## 7.3 SSH Access

```bash
ssh -i ~/.ssh/ch_vm browser@192.168.100.2
```

---

# Final Result

✅ Working VM
✅ GUI Desktop
✅ Mouse + Keyboard input
✅ Firefox browser usable
✅ Stable networking (no DHCP issues)
✅ Secure (SSH key only)
✅ Persistent VNC service

---

# Known Limitations

* Not GPU accelerated
* Slower than QEMU for GUI
* Designed for isolation, not performance

---

# If VM Fails

### Check logs:

```bash
cat ch.log
```

### Check kernel/initrd:

```bash
ls -lh vmlinuz initrd.img
```

### Check ports:

```bash
ss -tulpn | grep 5901
```

---

# End of Guide

