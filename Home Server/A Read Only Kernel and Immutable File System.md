# Making the guest OS root immutable (with SquashFS).
[THIS IS A WAY TO CREATE A `IMMUTABLE ROOTFS` BUT THE  STEP 4.1 IS FALING]

### 1. Prepare the System (Inside the Running Alpine Guest)

```bash
# Update and install tools
apk update
apk add squashfs-tools e2fsprogs

# Optional: Clean up logs, caches, etc. before squashing
rm -rf /var/cache/apk/*
rm -rf /tmp/*
rm -rf /var/log/*
```

### 2. Create the SquashFS Root Image

Exclude volatile/pseudo filesystems and any persistent data you want to keep separate:

```bash
# Create squashfs (exclude critical dirs)
mksquashfs / /rootfs.squashfs -b 1M -comp xz \
  -e proc sys dev tmp run mnt media rootfs.squashfs var/cache var/log lost+found
```

- Use `-comp zstd` or `xz` for good compression/speed trade-off.
- Place `rootfs.squashfs` on a separate partition or the boot drive (e.g., `/boot/rootfs.squashfs`).

**For better security**, you can add verity (dm-verity) for integrity checking later.

### 3. Bootloader Configuration (extlinux in Alpine)

Edit `/etc/update-extlinux.conf`:

```bash
# Add or modify
default_kernel_opts="quiet modules=loop,squashfs,sd-mod,usb-storage,virtio_net,virtio_pci,virtio_blk nomodeset"
```

Then:

```bash
update-extlinux
```

### 4. Initramfs / Boot Configuration for SquashFS Root

Alpine's default initramfs has some SquashFS support (via modloop for modules), but for a full SquashFS root you often need custom initramfs logic or kernel parameters + hooks.

**Recommended kernel command line** (add to your bootloader entry):
Edit `/etc/update-extlinux.conf`:

```
root=UUID=xxxx-xxxx  # or /dev/vda1
rootfstype=ext4
modules=loop,squashfs
init=/sbin/init
# Then use a custom init or script to mount squashfs and pivot_root
```

For a clean SquashFS root:

- Use an initramfs that mounts the SquashFS (as loop device) and does `pivot_root` or `switch_root`.
- Many people layer **OverlayFS** on top for a writable upper layer (tmpfs or persistent partition) — this keeps the base immutable while allowing runtime writes that vanish on reboot.

#### 4.1 Simple OverlayFS Approach (Recommended Balance)

This gives you immutable base + ephemeral writes:

In initramfs or early boot script:

```bash
mount -t squashfs -o loop /boot/rootfs.squashfs /mnt/lower
mount -t tmpfs none /mnt/upper
mount -t overlay overlay -o lowerdir=/mnt/lower,upperdir=/mnt/upper,workdir=/mnt/work /newroot
```

Then switch_root to `/newroot`.

### 5. Runtime Read-Only Hardening

Even with SquashFS:

- Mount key dirs as tmpfs in `/etc/fstab` or via rc scripts:
```
  tmpfs /tmp tmpfs defaults,noatime 0 0
  tmpfs /var/run tmpfs defaults,noatime 0 0
  tmpfs /var/tmp tmpfs defaults,noatime 0 0
```

- Use `apk add` with care — for immutable, prefer rebuilding the squashfs image for updates (atomic upgrades).

- Set `ro` on root mount.

### Better Alternatives for True Immutability

- **Alpine's official Immutable Root guide** (BTRFS-based with atomic snapshots and rollbacks) — more flexible than pure SquashFS.
- Tools like `rdbo/alpine-squash-rootfs` on GitHub for pre-made setups.
- For maximum security in VMs: Combine with **dm-verity** on the SquashFS image + measured boot.

### VM-Specific Tips (QEMU)

- Pass the squashfs via virtio disk or as part of the boot image.
- Use `virtio` drivers (already in your modules list).
- Snapshot the VM disk externally for easy resets.
- Consider running the guest diskless with NFS/9p for config if needed, keeping the OS layer immutable.

This setup makes malware extremely limited: it can run in memory during the session but cannot survive reboot or modify the base system. Rebuild the squashfs periodically for updates (or automate it).
