# Run Windows 11 VM (guest) With GPU passthrough Display using Looking Glass.

### Install Ubuntu (Host OS)
* update Ubuntu Os
    ` sudo apt update && sudo apt upgrade -y `
* Install virtualization tools
    `sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager ovmf -y`
* Enable libvirt
    `sudo systemctl enable --now libvirtd`
* Add user
    `sudo usermod -aG libvirt $USER`
* Reboot
    `sudo reboot`


### Enable IOMMU (CRITICAL)
* Edit GRUB
    `sudo nano /etc/default/grub`
    # find the `GRUB_CMDLINE_LINUX_DEFAULT=` and change it value base on the CPU
    # For Intel :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"`
    # For AMD  :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"`
* Update GRUB
    `sudo update-grub`
* Reboot
    `sudo reboot`


### Check IOMMU Groups
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Check the IOMMU Group
    `sudo dmesg | grep -i iommu` # _IOMMU_ disabled or not detected (no output or these lines)
* Ensure your GPU + audio device are in their own group.
    `find /sys/kernel/iommu_groups/ -type l`
    # The output is look like this 
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.0`
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.1`
    # Check the groupID [14] and the DEVICE_ID [0000:01:00.0]


### Bind GPU to VFIO (Passthrough)
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Edit the VFIO file
    `sudo nano /etc/modprobe.d/vfio.conf`
    # And Add the `options vfio-pci ids=10de:25ad,10de:2291`
* Update initramfs
    `sudo update-initramfs -u`


### Create Windows VM
* Open virt-manager
    `virt-manager`
    # Create VM:
        # ISO: Windows 11
        # Firmware: UEFI (OVMF)
        # CPU: host-passthrough
        # Disk: VirtIO
    # In VM settings:
        # PCI Host Device → your GPU
        # PCI Host Device → GPU audio
    # Inside VM Install Drivers:
        # VirtIO drivers
        # GPU drivers (NVIDIA/AMD)
* Download & install Looking Glass (Window)
* Enable IVSHMEM
    # In VM XML:
    `virsh edit win11`
    # Add:
    <shmem name='looking-glass'>
      <model type='ivshmem-plain'/>
        <size unit='M'>64</size>
    </shmem>


# Install Looking Glass Host
* Looking Glass Install
    `sudo apt install looking-glass-client -y`


# Start The VM
* Start VM
    `virt-manager`
* Start looking glass
    `looking-glass-client`
* Improves memory performance
    `echo 4096 | sudo tee /proc/sys/vm/nr_hugepages`
    




# Run Alpine (guest) With GPU passthrough Display using Looking Glass.

### Install Ubuntu (Host OS)
* update Ubuntu Os
    ` sudo apt update && sudo apt upgrade -y `
* Install virtualization tools
    `sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager ovmf -y`
* Enable libvirt
    `sudo systemctl enable --now libvirtd`
* Add user
    `sudo usermod -aG libvirt $USER`
* Reboot
    `sudo reboot`


### Enable IOMMU (CRITICAL)
* Edit GRUB
    `sudo nano /etc/default/grub`
    # find the `GRUB_CMDLINE_LINUX_DEFAULT=` and change it value base on the CPU
    # For Intel :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"`
    # For AMD  :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"`
* Update GRUB
    `sudo update-grub`
* Reboot
    `sudo reboot`


### Check IOMMU Groups
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Check the IOMMU Group
    `sudo dmesg | grep -i iommu` # _IOMMU_ disabled or not detected (no output or these lines)
* Ensure your GPU + audio device are in their own group.
    `find /sys/kernel/iommu_groups/ -type l`
    # The output is look like this 
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.0`
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.1`
    # Check the groupID [14] and the DEVICE_ID [0000:01:00.0]


### Bind GPU to VFIO (Passthrough)
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Edit the VFIO file
    `sudo nano /etc/modprobe.d/vfio.conf`
    # And Add the `options vfio-pci ids=10de:25ad,10de:2291`
* Update initramfs
    `sudo update-initramfs -u`


### Create Linux VM
* Open virt-manager
    `virt-manager`
    # Create VM
        # ISO: Arch Linux
        # RAM: 512MB – 2GB
        # CPU: 1–2 cores
        # Disk: 10–20GB (qcow2)
        # Network: NAT (default)


### Install Arch (minimal)
* Inside VM
    `pacstrap -K /mnt base linux linux-firmware`
* Then
    `genfstab -U /mnt >> /mnt/etc/fstab`
    `arch-chroot /mnt`
* Set basics
    `passwd`
    `pacman -S networkmanager openssh nano`
    `systemctl enable NetworkManager`
    `systemctl enable sshd`
* Exit + reboot
    `reboot`
* Only the Alpine Linux SSH setup
    `rc-update add sshd`
    `rc-service sshd start`
    
    
### Access via SSH
* From Ubuntu host
    `ssh [user]@[vm-ip]`


### Minimal GUI
* Install
    `pacman -S xorg-server xorg-xinit openbox xterm`
* Create .xinitrc
    `exec openbox-session`
* Start
    `startx`


### Improve VM performance
* In QEMU settings
        # CPU: host-passthrough
        # Disk: virtio
        # Network: virtio
        # Display: SPICE
        





#  Run ANY (guest) With QEMU GPU passthrough Display using Looking Glass.

### Final Architecture
Ubuntu (Host)
 ├── GPU 1 → Host display
 └── GPU 2 → VM (VFIO passthrough)
      └── QEMU/KVM
           └── Guest OS (Windows / Linux)
                └── Looking Glass (windowed display)

### Requirements (must have)
* 2 GPUs (or iGPU + dGPU)
* BIOS support:
	VT-d (Intel) / SVM + IOMMU (AMD)
* Secure Boot → OFF (recommended)

### Install virtualization stack
* Install virtualization
	`sudo apt update`
	`sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virt-manager ovmf bridge-utils -y`

* Enable
	`sudo systemctl enable --now libvirtd`
	`sudo usermod -aG libvirt $USER`

* Reboot
	`sudo reboot`


### Enable IOMMU (CRITICAL)
* Edit GRUB
    `sudo nano /etc/default/grub`
    # find the `GRUB_CMDLINE_LINUX_DEFAULT=` and change it value base on the CPU
    # For Intel :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"`
    # For AMD  :-- `GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"`
* Update GRUB
    `sudo update-grub`
* Reboot
    `sudo reboot`


### Check IOMMU Groups
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Check the IOMMU Group
    `sudo dmesg | grep -i iommu` # _IOMMU_ disabled or not detected (no output or these lines)
* Ensure your GPU + audio device are in their own group.
    `find /sys/kernel/iommu_groups/ -type l`
    # The output is look like this 
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.0`
    `/sys/kernel/iommu_groups/14/devices/0000:01:00.1`
    # Check the groupID [14] and the DEVICE_ID [0000:01:00.0]
    

### Bind GPU to VFIO (Passthrough)
* Find GPU ID and AUDIO ID
    `lspci -nn`
    # The output is look like this 
    `0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA107 [GeForce RTX 2050] [10de:25ad] (rev a1)`
    `0000:01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:2291] (rev a1)`
    # [0000:01:00.0] is a On ID and other is [10de:25ad]
* Edit the VFIO file
    `sudo nano /etc/modprobe.d/vfio.conf`
    # And Add the `options vfio-pci ids=10de:25ad,10de:2291`
* Update initramfs
    `sudo update-initramfs -u`
* Reboot
    `sudo reboot`
    
* Blacklist host drivers (Not Necessary)
	`sudo nano /etc/modprobe.d/blacklist.conf`
		# Add to the file
		# blacklist nouveau
		# blacklist nvidia


### Create VM in virt-manager
* Open
	`virt-manager`
* Create VM
	# ISO: Windows / Arch / Alpine
	# Firmware: UEFI (OVMF) ✅
	# CPU:
		Mode: host-passthrough
	# RAM:
		Windows: 8GB+
		Linux minimal: 1–2GB


### Attach GPU
* In VM settings
	# Add Hardware → PCI Host Device:
		GPU (VGA)
		GPU Audio


### Optimize VM (IMPORTANT)
* Set CPU
	# host-passthrough
		Disk:
			Bus: VirtIO
		Network: 
			VirtIO


### Install Guest OS
* If Windows
	# Install VirtIO drivers
	# Install GPU drivers
* If Linux (Arch/Alpine)
	# Install normally
	# Install GPU drivers if using passthrough


### Setup Looking Glass
* Add shared memory
	`virsh edit vm-name`
* Add
	<shmem name='looking-glass'>
  		<model type='ivshmem-plain'/>
  		<size unit='M'>64</size>
	</shmem>	
* Guest (VM)
	Install Looking Glass host


### Run it inside VM.
* Host (Ubuntu)
	`sudo apt install looking-glass-client -y`
* Run
	`looking-glass-client`


### Optional Performance Tweaks
* Hugepages
	`echo 4096 | sudo tee /proc/sys/vm/nr_hugepages`
