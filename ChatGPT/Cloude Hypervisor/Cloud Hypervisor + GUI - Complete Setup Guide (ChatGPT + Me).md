# Cloud Hypervisor + GUI - Complete Setup Guide (Me+Claude - Not Work)
Goal: Run Firefox browser inside Cloud Hypervisor microVM with GUI via VNC/SPICE
Requirements:
    - Ubuntu 22.04 LTS or later
    - KVM support (Intel VT-x or AMD-V)
    - 8GB RAM minimum
    - Rust compiler (will install)

---

## Part 1: System Preparation
### Step 1.1: Verify Virtualization
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
sudo modprobe kvm
sudo modprobe kvm_intel   # OR kvm_amd
sudo usermod -aG kvm $USER
newgrp kvm

### Step 1.2: Install Dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
build-essential \
git \
curl \
wget \
pkg-config \
libssl-dev \
qemu-utils \
cloud-image-utils \
genisoimage \
netcat-openbsd \
nbd-client \
tigervnc-viewer \
remmina \
python3 \
python3-pip

#### DEBUG
#### Update system might have missing repositories
sudo apt clean
sudo apt update
sudo add-apt-repository universe
sudo apt update

#### DEBUG
#### Verify sources list
cat /etc/apt/sources.list
#### You should see something like:
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse

#### DEBUG
#### If empty or broken then Run This
sudo tee /etc/apt/sources.list > /dev/null <<'EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
sudo apt update
     

## Part 2: Install Cloud Hypervisor
curl https://sh.rustup.rs -sSf | sh -s -- -y 
source $HOME/.cargo/env 

git clone https://github.com/cloud-hypervisor/cloud-hypervisor.git 
cd cloud-hypervisor 
cargo build --release 

sudo cp target/release/cloud-hypervisor /usr/local/bin/ 
cloud-hypervisor --version

mkdir -p ~/cloud-hypervisor-setup-GPT 
cd ~/cloud-hypervisor-setup-GPT


## Part 3: Create VM Image
### Step 3.1: Download Image
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img 
cp jammy-server-cloudimg-amd64.img ubuntu.img 
qemu-img resize ubuntu.img +10G

### Step 3.2: Extract Kernel + Initrd
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


## Part 4: Cloud-Init Configuration
### step 4.1: Generate SSH Key
ssh-keygen -t ed25519 -f ~/.ssh/ch_vm -N ""

### step 4.2: user-data
cat > user-data <<'EOF'
#cloud-config

hostname: browser-vm

users:
  - name: browser
    gecos: Browser User
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat ~/.ssh/ch_vm.pub)

#ssh_pwauth: false --> Enable password login if you wants Turing to this "true".
#disable_root: false

package_update: true
package_upgrade: true

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
      xrdb $HOME/.Xresources
      startxfce4 &

  - path: /etc/systemd/system/vncserver@.service
    permissions: '0644'
    content: |
      [Unit]
      Description=VNC Server
      After=network.target

      [Service]
      Type=forking
      User=browser
      PAMName=login
      PIDFile=/home/browser/.vnc/%H:%i.pid
      ExecStart=/usr/bin/vncserver :1 -geometry 1280x800 -depth 24
      ExecStop=/usr/bin/vncserver -kill :1
      Restart=always

      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p /home/browser/.vnc
  - echo "password" | vncpasswd -f > /home/browser/.vnc/passwd
  - chown -R browser:browser /home/browser/.vnc
  - chmod 600 /home/browser/.vnc/passwd

  - systemctl daemon-reexec
  - systemctl daemon-reload

  - systemctl enable ssh
  - systemctl start ssh

  - systemctl enable vncserver@1
  - systemctl start vncserver@1

final_message: "Cloud-init setup complete. VM ready."
EOF

#### DEBUG
#### Password login is DISABLED because of the
# only can access by SSH
lock_passwd: true

# If you really want console login
lock_passwd: false
passwd: 

### step 4.3: Meta-data
cat > meta-data <<'EOF'
instance-id: browser-vm-01
local-hostname: browser-vm
EOF

### step 4.4: FIXED Network Config (STATIC — NO DHCP ISSUE)
cat > network-config <<'EOF'
version: 2
ethernets:
  ens4:
    dhcp4: false
    addresses:
      - 192.168.100.2/24
    gateway4: 192.168.100.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 1.1.1.1
EOF

#### DEBUG
#### Instead of hardcoding ens4, you can use:
ethernets:
  any:
    match:
      name: "en*"

### step 4.5: Create Cloud Init ISO
# Every time you change somgthing you shloud run this command
cloud-localds -N network-config cloud-init.img user-data meta-data

## Part 5: Networking (TAP + NAT)
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

#### DEBUG
#### Verify TAP interface on host
ip a | grep tap0
## You should see
tap0: ... 192.168.100.1

#### DEBUG
#### DESTROY old TAP
sudo ip link set tap0 down || true
sudo ip tuntap del dev tap0 mode tap || true

#### DEBUG
#### Recreate TAP properly
sudo ip tuntap add dev tap0 mode tap
sudo ip addr add 192.168.100.1/24 dev tap0
sudo ip link set tap0 up

#### DEBUG
#### Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

#### DEBUG
#### NAT
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
# Replace wlan0 with your actual interface
ip a

#### DEBUG
#### Verify TAP
ip a show tap0
# You MUST see:
tap0: ... UP
inet 192.168.100.1/24


## Part 6: Launch VM
# you can run as "root"
cloud-hypervisor \
  --kernel ./vmlinuz \
  --initramfs ./initrd.img \
  --cmdline "console=hvc0 root=/dev/vda1 rw" \
  --cpus boot=2 \
  --memory size=2G \
  --disk path=ubuntu.img \
  --disk path=cloud-init.img,readonly=true \
  --net tap=tap0,mac=AA:BB:CC:DD:EE:FF \
  --console off \
  --serial null \
  --log-file ch.log

#### If You Want Performance Tuning
--disk path=ubuntu.img,num_queues=2,queue_size=128,image_type=qcow2 \
--disk path=cloud-init.img,readonly=true,image_type=raw \

#### DEBUG
  --console tty \
  --serial tty

## Part 7: Connect to VM
### step 7.1 Wait for VM
until nc -z 192.168.100.2 22; do sleep 2; done 
until nc -z 192.168.100.2 5901; do sleep 2; done

### step 7.2 VNC (GUI)
vncviewer 192.168.100.2:5901

### step 7.3 SSH Access
ssh -i ~/.ssh/ch_vm browser@192.168.100.2


## Part 8: Debug
### VM Fails
# Check logs
cat ch.log

# Check kernel/initrd:
ls -lh vmlinuz initrd.img

# Check ports:
ss -tulpn | grep 5901

# Check network inside VM and On Host
ip a
ip route

# Check network inside VM
ip a
journalctl -u systemd-networkd

#### You should see something like
ens3 or enp0s1

# If Something STILL Fails
# Run inside VM
cloud-init status --long
journalctl -u cloud-init
ip a

### VNC viewer
#### VNC viewer command mismatch os check it
which vncviewer || which xtigervncviewer

### Start VNC inside of VM
vncserver :1

### from host
vncviewer 192.168.100.2:1 || vncviewer 192.168.100.2:5901

### Network Connection
# Test host → TAP
ping 192.168.100.1

# Test VM → host 
ping 192.168.100.1

# Then hsot → VM
ping 192.168.100.2
nc -z 192.168.100.2 22

### Regenerate cloud-init image
rm -f cloud-init.img
cloud-localds -N network-config cloud-init.img user-data meta-data

### Rebuild cloud-init ISO
rm ubuntu.img   # rerun the Step 3.1
rm cloud-init.img
cloud-localds \
  --network-config=network-config \
  cloud-init.img \
  user-data

### SSH key issues
# Check your public key
cat ~/.ssh/ch_vm.pub

# remove the old vm SSH keys
ssh-keygen -f "/home/max/.ssh/known_hosts" -R "192.168.100.2"
