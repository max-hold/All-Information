[ 1. Run QEMU as unprivileged user with file descriptor passing for */dev/kvm* access ]
[ 2. Enable seccomp filtering with *--sandbox* on ]
[ 3. Use Alpine Linux guest for minimal attack surface and RAM usage ] 
[ 4. Configure virtio-gpu with *-vga virtio -display gtk,gl=on* for acceleration ]
[ 5. Set up networking with user-mode networking or isolated bridge ]
[ 6. Make it ephemeral by using tmpfs for VM disk (RAM-backed, destroyed on exit) ]
[ 7. Disable all virtio devices you don't need (use NAT with strictegress filtering) ]
8. If you need to download a file, use a "download to host" proxy service that scans the file before releasing it to the host filesystem.
9. QEMU has built-in support for libseccomp (enabled at build time with --enable-libseccomp). You can enable the sandbox with the command-line option:
`qemu-system-x86_64 ... -sandbox on[,strict=on]`
[ 10. Can run as unprivileged user with file descriptor passing :SELinux/AppArmor integration ]

