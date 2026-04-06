Implementation Recommendations

Based on QEMU's security documentation

1\. Run QEMU as unprivileged user with file descriptor passing for */dev/kvm* access

2\. Enable seccomp filtering with *--sandbox* on

3\. Use Alpine Linux guest for minimal attack surface and RAM usage

4\. Configure virtio-gpu with *-vga virtio -display gtk,gl=on* for acceleration

5\. Set up networking with user-mode networking or isolated bridge

6\. Make it ephemeral by using tmpfs for VM disk (RAM-backed, destroyed on exit)



Can run as unprivileged user with file descriptor passing

SELinux/AppArmor integration

















Implementation Roadmap Cloud Hypervisor VM.

1\.  Hypervisor: Cloud Hypervisor (Rust).

2\.  Guest OS: Minimal Linux (Buildroot or Alpine) with a hardened browser (Chrome/Firefox in kiosk mode).

3\.  Graphics Stack:

&#x20;  	Guest: `virtio-gpu` driver + `virglrenderer` (OpenGL over virtio).

&#x09;Host: Do not use a VNC viewer. Use a host-side compositor that understands `virtio-gpu` (integrate with a Wayland compositor or specialized framebuffer viewer that maps the GPU).

4\.  Security Hardening:

&#x09;Enable SECCOMP bpf filters on the CH process.

&#x09;Run the CH process as a non-root user with minimal capabilities (`CAP\\\_NET\\\_ADMIN`, `CAP\\\_SYS\\\_ADMIN` restricted).

&#x09;Disable all virtio devices you don't need (no network bridging, use NAT with strictegress filtering).

5\.  Clipboard/File Transfer:

&#x09;Disable completely.

&#x09;Do not implement shared folders. If you need to download a file, use a "download to host" proxy service that scans the file before releasing it to the host filesystem.

