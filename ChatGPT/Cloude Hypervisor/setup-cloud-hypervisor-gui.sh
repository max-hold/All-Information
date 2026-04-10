#!/bin/bash
set -e

echo "=== Cloud Hypervisor GUI VM Setup (Production-Grade) ==="

WORKDIR="$HOME/cloud-hypervisor-setup"
VM_IP="192.168.100.2"
HOST_IP="192.168.100.1"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

########################################
# 1. Install dependencies
########################################
echo "[1/8] Installing dependencies..."

sudo apt update
sudo apt install -y \
    build-essential git curl wget \
    qemu-utils cloud-image-utils genisoimage \
    netcat-openbsd nbd-client \
    tigervnc-viewer \
    python3 python3-pip \
    iproute2 iptables

########################################
# 2. Install Rust + Cloud Hypervisor
########################################
echo "[2/8] Installing Cloud Hypervisor..."

if ! command -v cloud-hypervisor &>/dev/null; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env

    git clone https://github.com/cloud-hypervisor/cloud-hypervisor.git
    cd cloud-hypervisor
    cargo build --release
    sudo cp target/release/cloud-hypervisor /usr/local/bin/
    cd ..
fi

########################################
# 3. Download and prepare image
########################################
echo "[3/8] Preparing Ubuntu image..."

wget -nc https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

cp jammy-server-cloudimg-amd64.img ubuntu.img
qemu-img resize ubuntu.img +10G

########################################
# 4. Extract kernel + initrd
########################################
echo "[4/8] Extracting kernel..."

sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 ubuntu.img
sleep 2

sudo mount /dev/nbd0p1 /mnt

cp /mnt/boot/vmlinuz-* ./vmlinuz
cp /mnt/boot/initrd.img-* ./initrd.img

sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0

########################################
# 5. Create cloud-init config
########################################
echo "[5/8] Creating cloud-init config..."

cat > user-data <<EOF
#cloud-config
hostname: browser-vm

users:
  - name: browser
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "NO_KEY")

packages:
  - xfce4
  - xfce4-goodies
  - tightvncserver
  - firefox
  - openssh-server

write_files:
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

  - path: /home/browser/.vnc/xstartup
    permissions: '0755'
    owner: browser:browser
    content: |
      #!/bin/bash
      startxfce4 &

runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - su - browser -c "mkdir -p ~/.vnc && echo password | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd"
  - systemctl daemon-reexec
  - systemctl enable vncserver@1
  - systemctl start vncserver@1

EOF

cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: browser-vm
EOF

cat > network-config <<EOF
version: 2
ethernets:
  eth0:
    match:
      name: "en*"
    addresses:
      - $VM_IP/24
    gateway4: $HOST_IP
    nameservers:
      addresses: [8.8.8.8,1.1.1.1]
EOF

cloud-localds -N network-config cloud-init.img user-data meta-data

########################################
# 6. Setup networking (TAP + NAT)
########################################
echo "[6/8] Setting up networking..."

sudo ip tuntap add tap0 mode tap user $USER || true
sudo ip addr add $HOST_IP/24 dev tap0 || true
sudo ip link set tap0 up

sudo sysctl -w net.ipv4.ip_forward=1

MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)

sudo iptables -t nat -A POSTROUTING -o $MAIN_IF -j MASQUERADE || true
sudo iptables -A FORWARD -i tap0 -j ACCEPT || true
sudo iptables -A FORWARD -o tap0 -j ACCEPT || true

########################################
# 7. Launch VM
########################################
echo "[7/8] Launching VM..."

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
  --log-file ch.log &

CH_PID=$!

########################################
# 8. Wait + connect
########################################
echo "[8/8] Waiting for VM..."

echo "Waiting for SSH..."
until nc -z $VM_IP 22; do sleep 2; done

echo "Waiting for VNC..."
until nc -z $VM_IP 5901; do sleep 2; done

echo "Opening GUI..."

vncviewer $VM_IP:5901 &

echo "======================================"
echo "VM READY"
echo "IP: $VM_IP"
echo "VNC: $VM_IP:5901"
echo "======================================"

wait $CH_PID
