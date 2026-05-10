**✅ Got it — here's the complete menu of everything you can do with QEMU's graphical output and GUI sharing for your Alpine kiosk VM.**

You've already explored the main paths (GTK native window, VNC, SPICE, Looking Glass, and the broken microVM attempts). Below is **every realistic option** you can combine right now (as of 2026 QEMU 9.x+ era), grouped by use-case, with pros/cons, exact command-line snippets for your Alpine setup, and how they help "share the GUI with the user" (seamless/native feel on host, remote access, multi-user, kiosk integration, etc.).

### 1. Native/Local Displays (Zero extra latency — best for your daily kiosk)
These open a real window on the host desktop, exactly like your current `-display gtk`.

| Option | Command snippet (add to your run.sh) | Pros | Cons | Best for "sharing GUI" |
|--------|--------------------------------------|------|------|------------------------|
| **GTK + VirGL 3D** (your current best) | `-device virtio-gpu-pci,virgl=on -display gtk,gl=on` | Smooth 2D/3D, hardware accel via host GPU, low CPU | Needs `mesa-dri-gallium` + `xf86-video-fbdev` in Alpine | Native window that feels like a real app |
| **SDL + VirGL** (often smoother scrolling) | `-device virtio-gpu-pci,virgl=on -display sdl,gl=on` | Slightly better input latency than GTK on some hosts | SDL window vs GTK theming | Full-screen kiosk feel |
| **GTK/SDL borderless + fullscreen kiosk** | Add: `-full-screen` or use host window manager rules (e.g. `wmctrl` or compositor script) | True kiosk mode — no title bar, no escape | Mouse/keyboard grab needed | One-click "launch browser window" that takes over screen |
| **virtio-gpu-pci + Venus (Vulkan)** (newer 2025+) | Same as VirGL but add guest Vulkan support (`apk add mesa-vulkan-virtio`) | Future-proof 3D/Vulkan accel | Still maturing | Games or WebGL-heavy kiosk |

**Tip for your Alpine kiosk**: Stick with `virtio-gpu-pci,virgl=on + gtk,gl=on`. It’s already the sweet spot for <200 MB RAM and instant Firefox kiosk.

### 2. Remote / Networked Protocols (share the GUI with other users/machines)
You already use VNC/SPICE — here are all the ways to expose the GUI over the network.

- **SPICE (still excellent)**: `-device virtio-gpu-pci -spice port=5930,disable-ticketing=on -device virtio-serial -chardev spicevmc,id=vdagent,name=vdagent -device virtserialport,chardev=vdagent,name=com.redhat.spice.0`  
  Then connect with `remote-viewer spice://localhost:5930` or `virt-viewer`.  
  **Share features**: Clipboard sync, file drag-drop, USB redirect, auto-resize, audio.  
  **Pro**: Best feature set for desktop-like sharing.  
  **Kiosk mode**: `remote-viewer --kiosk`.

- **VNC + noVNC (web browser access)**: `-vnc :0,password=off` + run noVNC on host.  
  Anyone with a browser can connect → perfect for "share GUI with user" over LAN/internet.

- **RDP (via xrdp in guest)**: Install `apk add xrdp` in Alpine, forward port.  
  Windows/macOS/Linux native clients love RDP. Feels more "native" than VNC.

- **Web-based full stack**: SPICE HTML5 client or Apache Guacamole (web portal for VNC/SPICE/RDP).  
  Great for sharing the kiosk browser with non-technical users.

### 3. Ultra-Low-Latency / Near-Native Sharing (your Looking Glass path + upgrades)
- **Looking Glass (you already have this)**: Still the king for <1 ms latency when you do full GPU passthrough.  
  Combine with your Alpine kiosk → install Looking Glass host in VM and run `looking-glass-client` on host.

- **DMA-BUF + virtio-gpu (zero-copy frames)**: Modern kernels + `virtio-gpu-pci` + guest driver support.  
  Pairs with GTK/SPICE for near-zero-copy display. (See Intel GVT-g guides but works on any virtio-gpu.)

- **Full GPU passthrough + Looking Glass/Sunshine**: Pass a real GPU slice (or second GPU) to the VM + use Looking Glass or Sunshine/Moonlight streaming.  
  **Sharing**: Stream the browser kiosk to any device (phone, tablet, another PC) with almost bare-metal performance.

### 4. Tools & Wrappers That Make Everything Easier
- **Quickemu** (highly recommended wrapper): One-command optimized QEMU launcher that auto-picks the best display (GTK/SDL/SPICE), enables VirGL, snapshots, etc.  
  It’s basically "what you’ve been building manually but 10× cleaner."

- **virt-viewer / remote-viewer in kiosk mode**: `virt-viewer --kiosk --attach qemu:///session/your-vm`  
  Turns any QEMU display into a dedicated fullscreen window.

- **virt-manager + custom display**: Use virt-manager for management but override display to GTK/SDL in the XML.

### 5. Extra "Share the GUI" Tricks (seamless/native feel)
- **Seamless mouse/keyboard**: `-device virtio-input-host-pci` or USB tablet + virtio-input.  
  Mouse seamlessly enters/leaves the window (no grab key).

- **Clipboard + file sharing**:  
  - SPICE + `spice-vdagent` in guest → copy/paste + drag files into the browser VM.  
  - `virtfs/9p` or virtio-fs for shared folders (`-virtfs local,path=~/shared,...`).

- **Embed in host desktop**: Run the QEMU window inside a host compositor (e.g., GNOME/KDE) or use `xdotool`/`wmctrl` scripts to make it behave like a native Firefox window.

- **Headless host sharing**: Pipe display to a virtual display server (Xvfb + VNC) or stream via ffmpeg/WebRTC.

- **Multi-monitor / multi-user**: virtio-gpu supports multiple heads. Or run multiple QEMU instances and share via a central web dashboard.

- **Recording / broadcasting the kiosk**: Add `-device virtio-vga` + pipe output to ffmpeg for live stream (Twitch/YouTube) or recording.

### Quick Recommendation for Your Exact Setup (Alpine kiosk)
**Best daily driver right now** (2026):  
`virtio-gpu-pci,virgl=on + -display gtk,gl=on` (or SDL)  
+ `virtio-input-host-pci` for seamless mouse  
+ temporary overlay snapshot (your current method)  
+ optional SPICE fallback for remote users.

If you want even simpler: Switch to **Quickemu** — it handles all the display/GPU/snapshot magic for you.

**Want me to give you the final polished `run.sh` + inside-Alpine config that combines the absolute best of everything above?**  
Or pick one specific path (e.g., "make GTK fullscreen kiosk + clipboard + web sharing") and I’ll write the exact commands + scripts.

Just tell me which direction you want to go next — I’m ready to build it. 🚀
