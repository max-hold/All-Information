# QEMU/KVM + Alpine + Firefox_Kiosk - Complete Debug Guide

---

## Part 1: System Preparation
### SSH Access (optional)

```bash
ssh browser-vm@localhost -p 2222
```

### No display and Slow graphics
- add to 'boot command'
```
-device virtio-vga \
-display gtk,gl=on \
```

### Disable USB inside VM
```
-device usb-kbd
-device usb-tablet

# DONOT use This
-virtfs
```

### For smoother UX (especially browser scrolling) add this
- add to 'boot command'
```
-device virtio-input-host-pci \
# instead of 
-device usb-tablet
```

### Mouse issues
- add to 'boot command'
```
-device usb-tablet \
```

### Enable networking (NAT default works)
```
-net nic -net user
```

### Remove unnecessary apps
- Inside the VM
`sudo apt remove -y firefox libreoffice*`

### Disable terminal access
- Inside the VM
`sudo chmod 700 /usr/bin/gnome-terminal`


### Shared folder
`-virtfs local,path=~/shared,mount_tag=shared,security_model=mapped,id=fs0` + `apk add 9pfs` in guest.

### Verification commands (after VM boots)
```
# Should show your normal user, NOT root
ps aux | grep qemu

# Seccomp is active
cat /proc/$(pidof qemu-system-x86_64)/status | grep Seccomp
```

### Optional: Isolated Bridge Networking (instead of user-mode)
### If you prefer a real bridge (still isolated from host internet):
```
# On host (once)
sudo ip link add br0 type bridge
sudo ip addr add 192.168.42.1/24 dev br0
sudo ip link set br0 up

# Then in QEMU command replace the netdev line with:
-netdev bridge,id=net0,br=br0 -device virtio-net-pci,netdev=net0
(Requires qemu-bridge-helper setuid.)
```

### Verification & Security Checklist
* QEMU runs as `qemuuser (ps aux | grep qemu)`
* Seccomp active `(cat /proc/$(pidof qemu-system-x86_64)/status | grep Seccomp)`
* FD passed `(ls -l /proc/$(pidof qemu)/fd/3 should show /dev/kvm)`
* virtio-gpu + GL acceleration visible in guest `(glxinfo | grep renderer)`

### SELinux / AppArmor integration (host hardening): 
- This part of the guide is **host hardening** — it tries to add an extra layer of security **on your Ubuntu host machine** (not inside the Alpine VM) so that even if QEMU has a serious bug or someone escapes the VM, the damage to your real computer is limited.
- Even if you are root or the user, you are only allowed to do these exact things defined in a policy.

* AppArmor: `sudo aa-enforce /etc/apparmor.d/usr.bin.qemu-system-x86_64` (It sandboxes the QEMU process itself on the host.)
* SELinux: 
```
sudo semanage fcontext -a -t qemu_exec_t "/usr/bin/qemu-system-x86_64"
restorecon -v /usr/bin/qemu-system-x86_64
```
- If you want to apply the useful part:

```bash
# Check if AppArmor profile for QEMU already exists
ls /etc/apparmor.d/*qemu*

# If you see a profile, just enforce it:
sudo aa-enforce /etc/apparmor.d/usr.bin.qemu-system-x86_64

# Check status
sudo aa-status | grep qemu
```

### Network default started 
```
sudo virsh net-start default
```

### Network default marked as autostarted
```
sudo virsh net-autostart default
```
### Check status
```
sudo virsh net-list --all
```
