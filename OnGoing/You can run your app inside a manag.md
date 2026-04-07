3\. Windows Sandbox automation

✔ Good for:

Testing

Running untrusted plugins or user content



4\. Sandboxie Plus (Not a VM system at all)

Runs apps in isolation inside Windows

No OS installation

No ISO support



&#x20;CLI control exists

&#x20;No VM creation

&#x20;No disk/CPU config like hypervisors



















1\. Core idea (what i trying to build)

You want:

&#x09;Browser runs in isolated VM/hypervisor But the browser GUI output should be visible.

&#x09;That’s basically mean A managed, disposable browser VM with monitored I/O.

&#x09;Only the browser runs in the isolated VM (boot straight to browser—no login, no heavy desktop).

&#x09;if Chrome is compromised → detect + kill immediately (Treat VM as throwaway)





Micro VM:

&#x09;Hyper-V



Key Hyper-V settings:

&#x09;Dynamic Memory:

&#x09;	Min: 512 MB

&#x09;	Max: 1500 MB



&#x09;Disable unnecessary devices

&#x09;Use checkpoint (snapshot) (only We setup, they can't change it)





VM Os:

&#x09;Alpine Linux



Run:

&#x09;Your Chromium Browser (Chromium in kiosk mode)

&#x09;Custom Script We provide



Boot directly into:

&#x09;start → launch Chromium only

&#x09;chromium close → VM will Close to



&#x09;No:

&#x09;	Terminal

&#x09;	File manager

&#x09;	Package manager



Track:

&#x09;File modifications

&#x09;Network(IP/URL)

&#x09;Downloads file



Control:

&#x09;File download/export

&#x09;Password storage (outside VM)



Prevent:

&#x09;Host compromise







2\. Best foundation: Hyper-V



Architecture:

Host (Windows)

&#x20;├── Controller Service

&#x20;├── Password Vault

&#x20;├── File Inspection and Sanitizer Service

&#x20;├── Log Store  

&#x20;└── Hyper-V 

&#x20;      └── Minimal OS (Alpine Linux)

&#x09;	 ├── Window system (very minimal GUI)

&#x09;	 ├── Chromium (your browser)

&#x09;	 ├── Monitor Agent (root-level)

&#x09;	 │     ├── Network monitor

&#x09;	 │     ├── File monitor

&#x09;	 │     └── Behavior detection

&#x09;	 ├── Policy Engine

&#x09;	 │     └── Kill / reset logic

&#x09;	 └── NO other apps, NO package manager





3\. Password isolation (very important)

&#x09;Store credentials in host, NOT VM.



Use:

Windows Credential Manager or own encrypted vault (Opensource)



Flow:

Browser requests credential

VM → Host via secure channel (named pipe / RPC)

Host injects credential (never stored in VM)



Similar to how Edge + WDAG handles secrets.







4\. Network monitoring (URL + IP tracking)



Inside VM:

Use Chromium hooks (DevTools Protocol)



Log:

&#x09;URLs

&#x09;Requests

&#x09;Headers



Outside VM (stronger approach):

&#x09;Hyper-V virtual switch monitoring



&#x09;Force VM traffic through a proxy (Recommended) and send the data to host end of the session:

&#x09;	mitmproxy

&#x09;	custom proxy



&#x09;Then you can log:

&#x09;	Destination IP

&#x09;	Domain

&#x09;	Full request/response







5\. File system tracking (inside VM)

Options:



A. Lightweight (recommended)

Inside VM:

Use Windows APIs:

&#x09;ReadDirectoryChangesW

&#x09;kernel minifilter driver (advanced)







6\. Secure file download/export pipeline

This is CRITICAL.

Only allow export via controlled pipeline (Download files, Password and password request, Network collected Data)



Flow:

&#x09;File downloaded inside VM

&#x09;File goes to quarantine folder in VM

&#x09;User clicks “Export”

&#x09;Host pulls file Through a Hyper-V Guest Services

&#x09;Shared folder (read-only from VM)



Host scans file:

&#x09;Antivirus

&#x09;Sandbox

&#x09;Hash check



Only then:

→ Move to host filesystem







7\. VM lifecycle (Application Guard style)

Make VM:

&#x09;Ephemeral (destroy after session)

&#x09;Snapshot-based



Using:

&#x09;Hyper-V checkpoints



Flow:

Start VM → Use browser → Collect logs → Destroy VM







8\. Communication channel (host ↔ VM)

Use:

&#x09;Named pipes

&#x09;Hyper-V sockets (VMBus)



This is how you:

&#x09;Send network collected data

&#x09;Request passwords

&#x09;Trigger file export







9\. Chromium integration points

Since you built a browser:



Hook into:

&#x09;Network layer (URL tracking)

&#x09;Download manager

&#x09;Cookie/password manager (disable inside VM, but Store Inside the Host VM)



Optional:

&#x09;Use Chromium DevTools Protocol







10\. Recommended stack (practical)

If I were building this:

&#x09;Isolation: Hyper-V micro-VM

&#x09;Browser: your Chromium build

&#x09;Network: forced proxy (host-controlled)

&#x09;File control: export pipeline

&#x09;Passwords: host vault + IPC



Logging:

&#x09;DevTools (browser)

&#x09;Proxy (network)

&#x09;Host (file export)



11\. Enforce “ONLY Chrome runs”

This is critical.



Use:

&#x09;Linux namespaces + cgroups

&#x09;AppArmor or SELinux



Recommended:

&#x09;AppArmor



Policy:

Only allow:

&#x09;Chromium binary

&#x09;Your monitor agent



Everything else:

→ blocked







12\. Attack detection (this is your “kill switch”)

You need a watchdog outside Chrome process.



Build a Monitor Agent (root-level)

It should Watch:

&#x09;New processes

&#x09;Suspicious syscall

&#x09;Memory spikes

&#x09;Unexpected file writes



Tools:

&#x09;auditd

&#x09;eBPF (advanced but powerful)





Detection logic examples

If Chrome is compromised, you’ll see:

&#x09;Spawning shell (/bin/sh, /bin/bash)

&#x09;Writing to system directories

&#x09;Opening raw sockets (bypassing proxy)



When detected:

Immediate action:

&#x09;kill -9 chrome

&#x09;trigger VM shutdown/reset











Hardening checklist (VERY important)

1\. No direct host access

Disable:

&#x09;Clipboard sharing

&#x09;Drive sharing

&#x09;Copy-paste



2\. Controlled file export only

One-way pipeline:

&#x09;VM → quarantine → host



3\. Force network through host

&#x09;Use proxy (host-controlled)

&#x09;Block direct internet from VM



4\. No secrets inside VM

&#x09;Passwords stored in host (as discussed earlier)



5\. Always reset VM

&#x09;Never reuse sessions





===========================================================



The key mindset shift:

Don’t try to “monitor everything”

Instead try to Control all entry/exit points (network + files + credentials)









6\. Network control (VERY important)

Inside VM:

&#x09;BLOCK all direct internet

&#x09;Force traffic through host proxy:

&#x09;	mitmproxy



Using firewall:

&#x09;iptables

Rule:

&#x09;Only allow traffic → host proxy

&#x09;Everything else → DROP





7\. File system lockdown

Inside VM:

&#x09;Root filesystem → read-only



Writable:

&#x09;/tmp

&#x09;/downloads (isolated)



Monitor:

&#x09;Any write outside allowed dirs → trigger alert



8\. Password system (secure design)

Do NOT store passwords in VM.



Flow:

&#x09;Chrome requests password

&#x09;Request goes to host

&#x09;Host returns credentials



Inside VM:

&#x09;No saved credentials

&#x09;No cookies persistence



9\. Sanitization pipeline

When user downloads:

&#x09;File stays in VM temp

&#x09;User clicks export

&#x09;File sent to host



Host:

&#x09;scans

&#x09;cleans

&#x09;Then released to user



10\. Session reset (your strongest defense)

Using Hyper-V:

&#x09;Always revert to snapshot Or destroy VM entirely





11\. If attacker fully compromises Chrome

Let’s be realistic:



They can:

&#x09;Run code inside VM

But they cannot:

&#x09;Access host (if configured right)

&#x09;Persist (because VM resets)



Your job is:

&#x09;Detect early and kill fast





12\. Performance (fits your 4GB goal)

With this setup:

&#x09;VM RAM: \~512MB–1GB

&#x09;Host: \~2–3GB

&#x09;Very usable



===============================================================



What you’re building is basically:

&#x09;A mini Remote Browser Isolation (RBI) system + zero-trust VM



Even big companies do this the same way:

&#x09;isolate

&#x09;monitor

&#x09;control exits

&#x09;reset everything







Hypervisor boundary is strong (same class used by Windows Defender Application Guard) But be honest about risks Even Hyper-V is not “magic”: 

&#x09;VM escape vulnerabilities (rare but real) Misconfigured shared folders = biggest risk

