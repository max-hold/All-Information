- **XCP-ng And ProxmoxVE** :-- an appliance hypervisor that requires a dedicated bare-metal installation using its own ISO image, replacing the host operating system entirely.

- **Kasm Workspaces** :-- This is literally built for "app streaming." Kasm streams only the app window to the user's browser (accessible via a local web interface). No full desktop unless you want one.

- **Apache Guacamole** :-- A web-based gateway. Connect it to the container via VNC or RDP, and configure it to launch only A app (via .xsession file or connection settings).

- **Qubes OS/Liteqube** :- A full standalone operating system designed to run directly on bare metal, each applications with its own kernel via `Xen hypervisor`, fully isolating them from the host and each other. Qubes OS requires its own installation as the primary OS.Qubes OS is uses the _Xen hypervisor_ _(type-1)_ to create lightweight VMs called "qubes" (or AppVMs). 
Each _qube_ runs its _own independent kernel and OS_ (_minimal Fedora, Debian, or Whonix template for Linux apps_). 
* _Hardware-level isolation_ (Xen + IOMMU) it cannot infect other qubes or the _minimal privileged host (dom0)_. Qubes appear side-by-side on a single desktop (just like normal apps), with colored window borders indicating the security domain (e.g., green for trusted work, red for untrusted). Installation replaces your current OS, but you can dual-boot or test in a VM first.

- **Firecracker** :- 

- **Cloud Hypervisor** :-

* PROXMOX
* VMWARE WROKSTATION PLAYER


- **WSL2 + GUI** :- Where a Linux kernel-level threat stays confined to the WSL2 VM, not directly impacting the Windows host kernel. Hardening measures can significantly reduce shared attack surfaces, making WSL2 behave more like a standalone VM.

- **Kata Containers** :-

- **CrosVM + Rust VM** :-

# virtualization 
To run _isolated guest kernels and OSes_ with native GUI inside virtual displays.
- **VirtualBox / VM Workstation** :- 

- **QEMU + KVM + VMM** :- 

- **GNOME Boxes** :-

- **Hyper-V** :-

# Linux name-spaces and management tools
- **Firejail** 
- **Bubblewrap** 
- **gVisor**
- **podman**
- **docker** + **Docker Manager**
- **podman** + **Podman Machine**
- **Kubernetes**


# Sandboxes
* _**Windows Sandbox for Windows**_ :- Windows Sandbox provides a disposable VM with a full Windows kernel, where you can install and run any browser isolated from the host.
* _**Sandboxie-Plus for Windows**_ :- offers user-mode sandboxing (shared kernel) but can integrate with VMs for stronger isolation.It isolates Windows processes.No OS installation.


# Displays
- **VFIO GPU Passthrough + Looking Glass** :- Extremely strong. The guest cannot touch the host (proper setup blocks DMA attacks). Malware in the guest stays contained.
Core components (all open-source):

- **VFIO/PCI passthrough + IOMMU** :- The guest VM gets direct, exclusive access to a physical GPU. 
- **Looking Glass** : Captures the guest's GPU framebuffer via shared memory and displays it in a low-latency window (or fullscreen) on your host desktop. Latency is near-zero; it feels native.
- **render the video stream yourself (e.g., via winit + Vulkan).**
- **SPICE/VNC** 
- **GPU passthrough**
- **X11/Wayland**


# Implementation Roadmap Cloud Hypervisor VM.
1.  Hypervisor: Cloud Hypervisor (Rust).
2.  Guest OS: Minimal Linux (Buildroot or Alpine) with a hardened browser (Chrome/Firefox in kiosk mode).
3.  Graphics Stack:
        Guest: `virtio-gpu` driver + `virglrenderer` (OpenGL over virtio).
        Host: Do not use a VNC viewer. Use a host-side compositor that understands `virtio-gpu` (integrate with a Wayland compositor or specialized framebuffer viewer that maps the GPU).
        
**X11 / Wayland / Hyprland**, They’re part of the **graphics stack**—they handle how graphical programs talk to your screen and input devices. 


Stream Server

* VNC 	 (XORG/ WINDOW MANAGER/ GNOME BOX/ OPEN BOX/ i3)
* XFCE4
* SPICE
* XVFB
* VITRO-GPU / VITRO-MANAGER
* X11 (Not Secure)
* TIGERVNC
* TightVNC
* Dummy Video Driver
* WAYLAND
* MOONLIGHT
* xRDP
