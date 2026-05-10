# A **read-only kernel + immutable rootfs** is one of the biggest upgrades you can make for a disposable kiosk VM.
[THIS IS A WAY TO CREATE A `IMMUTABLE ROOTFS` BUT THE  STEP 3 IS FALING]
The goal is:

* kernel cannot be modified at runtime
* root filesystem is read-only
* only temporary writable areas exist (`/tmp`, browser cache, runtime dirs)
* every reboot starts from identical state

This is much closer to how kiosk appliances and live systems behave.

Architecture:

```text
Kernel (read-only)
Root filesystem (SquashFS, read-only)
Writable tmpfs layers:
  /tmp
  /var
  /run
  /home/browser-vrun
  /home/brom
```

So malware can still mess around temporarily, but persistence becomes extremely difficult.

---

# 1. Install required packages

Inside Alpine:

```bash
apk add squashfs-tools alpine-conf rsync
```

---

# 2. Prepare clean root filesystem

Create working directory:

```bash
mkdir -p /build/rootfs
```

Copy system:

```bash
rsync -aAX \
  --exclude=/proc \
  --exclude=/sys \
  --exclude=/dev \
  --exclude=/tmp \
  --exclude=/run \
  --exclude=/mnt \
  --exclude=/media \
  / /build/rootfs
```

This gives a clean copy without runtime junk.

---

# 3. Make root immutable with SquashFS

Build compressed read-only image:

```bash
mksquashfs /build/rootfs /boot/rootfs.squashfs -comp xz -b 1M \
    -e proc sys dev tmp run mnt media rootfs.squashfs var/cache var/log lost+found  
```

This creates:

```text
/boot/rootfs.squashfs
```

That file becomes your immutable OS image.

---

# 4. Boot using initramfs overlay

We need boot logic:

1. mount squashfs read-only
2. mount tmpfs writable layer
3. overlay them

Create init script:

```bash
mkdir -p /tmp/initramfs
nano /tmp/initramfs/init
```

Paste:

```sh
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

mkdir /ro
mkdir /rw
mkdir /newroot

mount -o ro -t squashfs /dev/vda1 /ro

mount -t tmpfs tmpfs /rw
mkdir -p /rw/upper
mkdir -p /rw/work

mount -t overlay overlay \
  -o lowerdir=/ro,upperdir=/rw/upper,workdir=/rw/work \
  /newroot

exec switch_root /newroot /sbin/init
```

Make executable:

```bash
chmod +x /tmp/initramfs/init
```

---

# 5. Build custom initramfs

Package it:

```bash
cd /tmp/initramfs
find . | cpio -H newc -o | gzip > /boot/initramfs-immutable.img
```

Now you have:

```text
/boot/initramfs-immutable.img
```

---

# 6. Update bootloader

Edit:

```bash
nano /etc/update-extlinux.conf
```

Set:

```bash
default_kernel_opts="quiet"
initfs=/boot/initramfs-immutable.img
```

Then rebuild:

```bash
update-extlinux
```

Or directly edit:

```bash
nano /boot/extlinux.conf
```

Use:

```text
LABEL kiosk
    KERNEL /boot/vmlinuz-virt
    INITRD /boot/initramfs-immutable.img
    APPEND quiet
```

---

# 7. Read-only mount enforcement

Inside immutable system, set fstab:

```bash
nano /etc/fstab
```

Use:

```fstab
tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0
tmpfs /run tmpfs defaults,nosuid,nodev 0 0
tmpfs /var tmpfs defaults,nosuid,nodev 0 0
tmpfs /home/browser-vm tmpfs defaults 0 0
```

This means:

* downloads temporary
* browser profile temporary
* logs temporary

Everything disappears on reboot.

---

# 8. Protect kernel modules

Kernel is still loaded, but stop runtime module loading.

Disable module insertion:

```bash
echo 1 > /proc/sys/kernel/modules_disabled
```

Persist:

```bash
nano /etc/local.d/kernel-lock.start
```

Add:

```sh
#!/bin/sh
echo 1 > /proc/sys/kernel/modules_disabled
mount -o remount,ro /
```

Enable:

```bash
chmod +x /etc/local.d/kernel-lock.start
rc-update add local
```

After boot:

* no module load
* no unload

Kernel surface reduced.

---

# 9. Lock boot files

Protect `/boot`

```bash
mount -o remount,ro /boot
```

Or in fstab:

```fstab
/dev/vda1 /boot ext4 ro 0 0
```

Prevents kernel tampering.

---

# 10. Browser writable exceptions

Firefox needs writable paths.

Create startup wrapper:

```bash
nano /usr/local/bin/firefox-run
```

```sh
#!/bin/sh

mkdir -p /tmp/firefox-profile
exec firefox \
  --profile /tmp/firefox-profile \
  --kiosk https://google.com
```

Make executable:

```bash
chmod +x /usr/local/bin/firefox-run
```

Now browser state is ephemeral.

---

# 11. Verify immutability

After reboot:

Try:

```bash
touch /etc/test
```

Should fail or disappear after reboot.

Try:

```bash
mount | grep " / "
```

Should show overlay/squashfs combo.

---

# 12. Combine with your disposable overlay

Your existing QEMU overlay still matters.

So now you have two layers:

```text
QEMU overlay (discard VM disk changes)
+
guest immutable squashfs
```

That’s belt + suspenders.

A compromise would have to defeat both.

---

# Final architecture

```text
Host
└── QEMU/KVM
    └── Alpine
        ├── read-only kernel
        ├── squashfs immutable root
        ├── tmpfs writable overlay
        ├── Firefox seccomp sandbox
        └── disposable browser session
```

Security properties:

✔ no persistence
✔ rootfs immutable
✔ kernel modules locked
✔ browser profile ephemeral
✔ automatic clean reboot

---

## Optional next upgrade

If you really want to keep going down the rabbit hole:

* Linux dm-verity (filesystem integrity verification)
* signed kernel + signed rootfs
* measured boot / TPM attestation

That’s when your kiosk starts acting less like a browser VM and more like a tiny stubborn appliance that distrusts everyone equally.

