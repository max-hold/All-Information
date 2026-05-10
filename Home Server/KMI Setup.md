# PHASE 1: HOST PREPARATION (Ubuntu 24.04)

## Step 1.1: Install Required Packages
### Run this on YOUR laptop (i7-12650H), not in this chat
```
sudo apt update && sudo apt install -y \
    qemu-kvm \
    virt-manager \
    libvirt-clients \
    libvirt-daemon-system \
    bridge-utils \
    virtinst \
    cpu-checker \
    cloud-init \
    cloud-image-utils \
    pciutils \
    linux-headers-$(uname -r)
```

### Expected Output:
```
[sudo] password for yourusername: 
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Get:2 http://security.ubuntu.com/ubuntu noble-security InRelease [129 kB]
...
Setting up qemu-kvm (1:8.2.1+dfsg-1ubuntu4) ...
Setting up virt-manager (1:5.1-0ubuntu3) ...
Processing triggers for hicolor-icon-theme (0.17-2) ...
```

### Verification:
```
kvm-ok
```

### Expected Output:
```
INFO: /dev/kvm exists
KVM acceleration can be used
```


## Step 1.2: Enable IOMMU in GRUB (Intel CPU)
### Check current kernel parameters
```
cat /proc/cmdline
```

### Expected Output:
```
BOOT_IMAGE=/boot/vmlinuz-6.8.0-20-generic root=UUID=xxx ro quiet splash
```

### Edit GRUB
```
sudo nano /etc/default/grub
```

### Find this line:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
```

### Change to:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:25ad,10de:2291"
```
- Note: The PCI IDs **10de:25ad** (RTX 2050) and **10de:2291** (NVIDIA audio) are placeholders. 
- We'll get your actual IDs running `lspci -nn | grep -i nvidia`. 

### Update GRUB (Legacy BIOS uses update-grub):
```
sudo update-grub
```

### Expected Output:
```
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-20-generic
Found initrd image: /boot/initrd.img-6.8.0-20-generic
done
```

### Reboot:
```
sudo reboot
```


## Step 1.3: Verify IOMMU is Active
### Check IOMMU is enabled
```
sudo dmesg | grep -i -e DMAR -e IOMMU
```

### Expected Output:
```
[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.8.0-20-generic root=UUID=xxx ro quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:25ad,10de:2291
[    0.012345] DMAR: IOMMU enabled
[    0.012345] DMAR: Host address width 39
[    0.012345] iommu: Default domain type: Passthrough
```
### Check IOMMU groups:
```
#!/bin/bash
# Save as ~/check_iommu.sh and run: chmod +x ~/check_iommu.sh && ~/check_iommu.sh

shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```
### Expected Output Example:
```
IOMMU Group 0:
	00:00.0 Host bridge [0600]: Intel Corporation 12th Gen Core Processor Host Bridge/DRAM Registers [8086:4641]
IOMMU Group 1:
	00:02.0 VGA compatible controller [0300]: Intel Corporation Alder Lake-P GT2 [UHD Graphics] [8086:46a6]
...
IOMMU Group 12:
	01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad]
	01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio [10de:2291]
```
- Critical: Your RTX 2050 **should be in its own IOMMU group** (not shared with other devices). If it shares a group with the Intel GPU or USB controller, we'll need the ACS patch (more complex).

## Step 1.4: Identify GPU PCI IDs
### Get exact PCI IDs for your NVIDIA GPU
```
lspci -nn | grep -i nvidia
```

### Expected Output:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio [10de:2291] (rev a1)
```

### Get Intel GPU ID (for reference):
```
lspci -nn | grep -i vga
```

### Expected Output:
```
00:02.0 VGA compatible controller [0300]: Intel Corporation Alder Lake-P GT2 [UHD Graphics] [8086:46a6] (rev 0c)
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)
```

## Step 1.5: Configure VFIO-PCI (GPU Passthrough)
### Create VFIO configuration:
```
sudo nano /etc/modprobe.d/vfio.conf
```

### Add content:
```
options vfio-pci ids=10de:25ad,10de:2291
options vfio-pci disable_vga=1
```
- Note: Replace 10de:25ad,10de:2291 with your actual IDs from `lspci -nn | grep -i nvidia`.

### Update initramfs:
```
sudo update-initramfs -u
```

### Expected Output:
```
update-initramfs: Generating /boot/initrd.img-6.8.0-20-generic
```

### Reboot:
```
sudo reboot
```

## Step 1.6: Verify VFIO Binding
### Check NVIDIA GPU is bound to vfio-pci
```
lspci -nnk | grep -A 2 -i nvidia
```

### Expected Output:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)
	Kernel driver in use: vfio-pci
	Kernel modules: nvidiafb, nouveau
01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio [10de:2291] (rev a1)
	Kernel driver in use: vfio-pci
	Kernel modules: snd_hda_intel
```
- Key indicator: Kernel driver in use: vfio-pci (not nvidia or nouveau).

### Check VFIO modules are loaded:
```
lsmod | grep vfio
```

### Expected Output:
```
vfio_pci               16384  0
vfio_pci_core          65536  1 vfio_pci
vfio_iommu_type1       40960  0
vfio                   36864  2 vfio_pci_core,vfio_iommu_type1
irqbypass              16384  1 vfio_pci_core
```



# PHASE 2: CREATE VM TEMPLATE WITH CLOUD-INIT

## Step 2.1: Download Cloud Image
### Create directory for VMs
```
mkdir -p ~/vm-images && cd ~/vm-images
```

### Download Ubuntu 24.04 cloud image (minimal, ~700MB)
```
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

###  Expected Output:
```
--2024-04-18 14:00:00--  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
Resolving cloud-images.ubuntu.com... 91.189.88.247
Connecting to cloud-images.ubuntu.com|91.189.88.247|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 758153216 (723M) [application/octet-stream]
Saving to: 'noble-server-cloudimg-amd64.img'
...
100%[====================================>] 758,153,216  12.3MB/s   in 58s
```

### Resize image (add 10GB for browser usage):
```
qemu-img resize noble-server-cloudimg-amd64.img +10G
```
### Expected Output:
```
Image resized.
```

## Step 2.2: Create Cloud-Init Configuration
### Create config directory:
```
mkdir -p ~/vm-configs
cd ~/vm-configs
```

### Create user-data file
```
cat > ~/vm-configs/user-data << 'EOF'
#cloud-config
hostname: secure-browser
manage_etc_hosts: true
fqdn: browser-vm.local

# Disable password authentication entirely, use SSH keys
disable_root: false
ssh_pwauth: false
chpasswd:
  expire: false

users:
  - name: browser
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    home: /home/browser
    lock_passwd: true  # No password, key only
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIhz2GK/XCUj4i6Q5yQJNL1MXMY0RxzPV2QrBqfHrDq browser-vm-key

# Auto-login to graphical session (if you install desktop)
system_info:
  default_user:
    name: browser
    gecos: Browser User
    groups: [adm, cdrom, dip, plugdev, lxd, sudo]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash

# Run commands on first boot
runcmd:
  - sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - echo "browser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/browser-nopasswd
  - chmod 440 /etc/sudoers.d/browser-nopasswd
EOF
```
- Alternative: Console Login Fix (If SSH Not Available)
If you must use the serial console, add this to user-data:
# Add to user-data
```
chpasswd:
  list: |
    browser:browser123
  expire: False
```
# Enable console login
```
runcmd:
  - systemctl enable serial-getty@ttyS0
  - systemctl start serial-getty@ttyS0
```
# Login with:
```
    Username: browser
    Password: browser123
```

### Generate SSH Key Pair (Host Side)
```
ssh-keygen -t ed25519 -C "browser-vm-key" -f ~/.ssh/browser-vm-key -N ""
```

### Expected Output:
```
Generating public/private ed25519 key pair.
Your identification has been saved in /home/max/.ssh/browser-vm-key
Your public key has been saved in /home/max/.ssh/browser-vm-key.pub
```

### Get the public key:
```
cat ~/.ssh/browser-vm-key.pub
```

### Expected Output:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIhz2GK/XCUj4i6Q5yQJNL1MXMY0RxzPV2QrBqfHrDq browser-vm-key
```
- Copy this key into the user-data file (replace the placeholder key in Step 1).

### Create Meta-Data File (Optional but Recommended)
```
cat > ~/vm-configs/meta-data << 'EOF'
instance-id: browser-vm-001
local-hostname: secure-browser
EOF
```

### Expected Output: 
```
(no output, file created)
```


## Step 2.4: Create Network Bridge (Isolated VM Network)
### Create Network Bridge
```
sudo nano /etc/netplan/01-vm-bridge.yaml
```

### Add content:
```
network:
  version: 2
  bridges:
    br-vm:
      dhcp4: no
      addresses: [192.168.100.1/24]
      interfaces: []
```

### Apply network config:
```
sudo netplan apply
```

### Expected Output:
```
# (No output if successful, or network restart message)
```

### Verify bridge:
```
ip addr show br-vm
```

### Expected Output:
```
3: br-vm: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.1/24 scope global br-vm
       valid_lft forever preferred_lft forever
```


## Step 2.5: Create the Base VM (Template)
### Create the VM Template
```
cd ~/vm-images && \
virt-install \
  --name browser-template-2 \
  --memory 4096 \
  --vcpus 2 \
  --cpu host \
  --disk path=$HOME/vm-images/noble-server-cloudimg-amd64-2.img,format=qcow2,bus=virtio,cache=none \
  --network bridge=br-vm,model=virtio \
  --graphics none \
  --console pty,target_type=serial \
  --os-variant ubuntu24.04 \
  --import \
  --noautoconsole
```

### Destroy template 
```
sudo virsh destroy browser-template-2 2>/dev/null; sleep 2
```

###  Expected Output:
```
Starting install...
Allocating 'noble-server-cloudimg-amd64.img'                                     |    0 B  00:00:00     
Creating domain...                                                                 |    0 B  00:00:00     
Domain creation completed.                                                                          
Waiting for domain to get an IP address...                                                         
```

### Check VM status:
```
sudo virsh list --all
```

### Expected Output:
```
 Id   Name                 State
---------------------------------------
 1    browser-template-2     running
```


## Step 2.6: Inject Cloud-Init & Configure VM
### Create ISO with cloud-init config
```
cd ~/vm-configs && \
cloud-localds -v ~/vm-images/cloud-init.iso ~/vm-configs/user-data ~/vm-configs/meta-data
```

### Expected Output:
```
wrote /home/max/vm-images/cloud-init.iso
with filesystem label=cidata
```

### Check the ISO was created:
```
ls -lh ~/vm-images/cloud-init.iso
```

### Expected Output:
```
-rw-r--r-- 1 max max 384K Apr 18 16:45 /home/max/vm-images/cloud-init.iso
```

### Attach ISO to VM:
```
sudo virsh attach-disk browser-template-2 ~/vm-images/cloud-init.iso sdb --type cdrom --config
```

### Detach ISO file
```
sudo virsh change-media browser-template-2 sdb --eject --config 2>/dev/null
```

### Expected Output:
```
Disk attached successfully
```

### Start VM with console
```
sudo virsh start browser-template-2 && \
sudo virsh console browser-template-2
# Check the Logs `sudo virsh log browser-template-2`
```

###  Shutdown VM
```
sudo virsh shutdown browser-template-2
```

```
Login credentials:

    Username: browser
    Password: browser (or whatever you set in user-data)
```

### Expected Output:
```
[OK] Finished cloud-init-local.service...
[OK] Reached target cloud-config.target

Ubuntu 24.04 LTS browser-vm ttyS0

browser-vm login: _
```

### Login via SSH (Recommended Method)
# Get VM IP
```
VM_IP=$(sudo virsh domifaddr browser-template-2 | grep ipv4 | awk '{print $4}' | cut -d/ -f1)
echo "VM IP: $VM_IP"
```
# SSH with key (no password!)
```
ssh -i ~/.ssh/browser-vm-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null browser@$VM_IP
```

### Expected Output:
```
VM IP: 192.168.100.42
Warning: Permanently added '192.168.100.42' (ED25519) to the list of known hosts.
browser@secure-browser:~$ _
```

### After logging in as 'browser' user
```
sudo apt update && sudo apt install -y firefox-esr chromium-browser
```

### Expected Output:
```
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
...
Setting up firefox-esr (1:124.0.2+build1) ...
Setting up chromium-browser (3:124.0.6367.78-1) ...
```

### Shutdown VM:
```
sudo shutdown now
```



# PHASE 3: GPU PASSTHROUGH SETUP
## Step 3.1: Get PCI IDs for RTX 2050
```
lspci -nn | grep -i nvidia
```

### Expected Output (YOUR system):
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio [10de:2291] (rev a1)
```
- Note: 10de:25ad = GPU, 10de:2291 = Audio

## Step 3.2: Bind GPU to VFIO (Already partially done in Phase 1)

###Verify current binding:
```
lspci -nnk | grep -A 2 -i nvidia
```

### Expected Output:
```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)
	Subsystem: Lenovo Device [17aa:3a5e]
	Kernel driver in use: vfio-pci
	Kernel modules: nvidiafb, nouveau
01:00.1 Audio device [0403]: NVIDIA Corporation GA107 High Definition Audio [10de:2291] (rev a1)
	Subsystem: Lenovo Device [17aa:3a5e]
	Kernel driver in use: vfio-pci
```
- Critical: Must show Kernel driver in use: vfio-pci (not nvidia/nouveau)

## Step 3.3: Configure VM for GPU Passthrough
### Edit VM XML:
```
sudo virsh edit browser-template-2
```

### Add before </devices> section:
```
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
</hostdev>
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
  </source>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
</hostdev>
```
- Note: Adjust bus='0x01' to match your actual bus number from Step 3.1 (likely 01 or 03)

## Step 3.4: Install Looking Glass (Host Side)
### Install dependencies
```
sudo apt install -y binutils-dev cmake gcc libsdl2-dev libsdl2-ttf-dev \
    libgl1-mesa-dev libegl1-mesa-dev libspice-protocol-dev \
    fontconfig-config libfontconfig1-dev
```

### Clone and build Looking Glass:
```
cd ~ && git clone https://github.com/gnif/LookingGlass.git && \
cd LookingGlass && git checkout Release/B7 && \
mkdir build && cd build && \
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
make -j$(nproc) && \
sudo make install
```

### Expected Output:
```
[  100%] Built target looking-glass-client
[100%] Built target looking-glass-host
Install the project...
-- Installing: /usr/local/bin/looking-glass-client
```

## Step 3.5: Configure Looking Glass
### Create config directory:
```
mkdir -p ~/.config/looking-glass
```

### Create config file:
```
cat > ~/.config/looking-glass/client.ini << 'EOF'
[app]
shmFile=/dev/shm/looking-glass
inputCapture=yes
inputRaw=no
inputEscapeKey=KEY_RIGHTCTRL
inputGraceTime=5
EOF
```


# PHASE 4: AUTOMATION & DISPOSABLE WORKFLOW
## Step 4.1: Create Snapshot Script
```
cat > ~/vm-scripts/launch-browser.sh << 'EOF'
#!/bin/bash
VM_NAME="browser-$(date +%s)"
TEMPLATE="browser-template-2"

# Create new VM from template
sudo virt-clone \
  --original-name "$TEMPLATE" \
  --name "$VM_NAME" \
  --file ~/vm-images/"$VM_NAME".qcow2 \
  --auto-clean

# Start VM
sudo virsh start "$VM_NAME"

# Wait for boot
sleep 10

# Launch Looking Glass
looking-glass-client -c /dev/null -g -m -p -F -S -d yes &
LG_PID=$!

# Wait for user to close Looking Glass
wait $LG_PID

# Destroy VM when done
sudo virsh destroy "$VM_NAME"
sudo virsh undefine "$VM_NAME" --remove-all-storage
EOF
chmod +x ~/vm-scripts/launch-browser.sh
```

## Step 4.2: Create One-Command Launcher
```
cat > ~/.local/bin/secure-browser << 'EOF'
#!/bin/bash
# Poor Man's Qubes - Secure Browser Launcher
set -e

VM_NAME="browser-$(date +%s)"
TEMPLATE="browser-template-2"
IMG_PATH="$HOME/vm-images"
CONFIG_PATH="$HOME/vm-configs"

echo "[*] Creating disposable browser VM: $VM_NAME"

# Clone from template
sudo virt-clone \
  --original-name "$TEMPLATE" \
  --name "$VM_NAME" \
  --file "$IMG_PATH/$VM_NAME.qcow2" \
  --auto-clean 2>/dev/null || {
    echo "[!] Failed to create VM"
    exit 1
}

# Start VM
sudo virsh start "$VM_NAME"

# Wait for network
sleep 5

# Get VM IP
VM_IP=$(sudo virsh domifaddr "$VM_NAME" | grep ipv4 | awk '{print $4}' | cut -d/ -f1)

echo "[*] VM IP: $VM_IP"

# Launch Looking Glass
echo "[*] Starting Looking Glass..."
looking-glass-client -s -d yes &
LG_PID=$!

# Optional: Launch browser directly via SSH
# ssh -X browser@$VM_IP firefox &

wait $LG_PID

echo "[*] Closing VM..."
sudo virsh destroy "$VM_NAME"
sudo virsh undefine "$VM_NAME" --remove-all-storage

echo "[*] Disposable browser session complete."
EOF
chmod +x ~/.local/bin/secure-browser
```

### Add to PATH:
```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## Step 4.3: Desktop Integration
### Create .desktop file:
```
cat > ~/.local/share/applications/secure-browser.desktop << 'EOF'
[Desktop Entry]
Name=Secure Browser
Comment=Disposable browser VM with GPU passthrough
Exec=/home/YOUR_USERNAME/.local/bin/secure-browser
Icon=firefox
Type=Application
Terminal=true
Categories=Network;WebBrowser;
EOF
```
- Replace YOUR_USERNAME with your actual username:

```
sed -i "s/YOUR_USERNAME/$USER/" ~/.local/share/applications/secure-browser.desktop
```

# FINAL VERIFICATION COMMANDS
## Run these to verify everything works:

# 1. Check IOMMU is active
```
sudo dmesg | grep -i "iommu.*enabled"
```
# 2. Check GPU is bound to vfio-pci
```
lspci -nnk | grep -A 2 -i nvidia
```
# 3. Check VM template exists
```
sudo virsh list --all --inactive | grep browser-template-2
```
# 4. Check Looking Glass is installed
```
which looking-glass-client
```
# 5. Test launch script (creates disposable VM)
```
secure-browser
```

### Expected Final Output:
```
[*] Creating disposable browser VM: browser-1713442801
[*] VM IP: 192.168.100.42
[*] Starting Looking Glass...
# (Looking Glass window opens with VM display)
# (When you close Looking Glass window:)
[*] Closing VM...
[*] Disposable browser session complete.
```
