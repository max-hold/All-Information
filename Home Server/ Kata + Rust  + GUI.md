1. Project structure (Rust + Kata + GUI)
    Host (Rust)
        Use Tauri for the GUI (one window that looks like a browser).
        Write a Rust controller that:
            Starts a Kata container (or a small Firecracker VM) each time the user opens a domain.
            Sends URL to the container, then starts a local VNC/WebRTC proxy.

    Isolated VM / Kata side
        Minimal Linux image with:
            Firefox
            VNC server (or a simple WebRTC‑based video stream)

        Enforce 1‑session‑per‑VM policy.

    Interaction model (mouse/keyboard)
        User clicks/keys in the Tauri window.
        Rust backend forwards events into the VM (via VNC input or WebSocket + a tiny input‑proxy).
        VM sends back video frames; Tauri displays them.

    Security / “isolation” story
        If the browser is pwned, the attacker is stuck in the VM/container.
        When the user closes the tab, you destroy that VM / Kata pod (no persistency).



2. I preferred stack is :- Kata + Tauri GUI, or Firecracker VM + Tauri GUI. Desired demo scenario: e.g., “open any website, destroy VM on close, log visited URLs”.

