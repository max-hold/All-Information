# An Enterprise Browser
- An enterprise browser is basically a browser with IT/security controls built into or wrapped around the browser layer, instead of relying only on OS lockdown, VPN, or endpoint agents. It’s designed for:
    BYOD / unmanaged devices
    contractors
    remote workers
    kiosk terminals
    zero-trust access
    SaaS-heavy organizations

- Modern enterprise browsers are often Chromium-based and focus on browser-level control rather than OS-level control.


## Common Features 

1. Security / Control (Browser policy management)
- Admins can centrally control:
        homepage
        extensions
        bookmarks
        allowed URLs 
        proxy settings
        certificates 
        updates 
        browser flags

2. URL allowlist / denylist
- Block or allow:
        specific domains
        regex URLs
        categories
        only allow internal portal
        block downloads from random domains

3. Kiosk mode / fullscreen lockdown
- Important for your project.
        fullscreen
        hide address bar
        disable tab creation
        disable browser exit
        disable F11/Alt+Tab/Ctrl+N etc.
        launch on startup
        Extension management (force install extensions/ block extension installs/ allow only approved extensions)

4. Download restrictions
        disable downloads
        restrict file types
        restrict save locations
        Clipboard controls (copy/ paste/ cut/ drag drop/ clipboard read)

5. Print restrictions
        printing
        print to PDF
        
6. Screenshot blocking
        screenshots
        screen recording
        clipboard image capture
        
7. File upload restrictions
        uploads to personal apps
        uploads to unsanctioned SaaS
        
8. Session persistence controls
        clear cookies on exit
        wipe local storage
        wipe cache
        wipe history
        force ephemeral sessions

9. Identity integration
        SSO
        SAML
        OAuth
        MFA
        IdP

10. Audit logging
        visited URLs
        downloads
        uploads
        clipboard actions
        login events
        
        
## Premium Features (Paid tiers)

1. Data Loss Prevention (DLP)
        block copying customer data
        block downloading PDFs from Salesforce
        block uploads to ChatGPT or Dropbox

2. Per-site policies
- Community discussions mention this as a major differentiator.
- This is likely one of the most valuable features for your design.
Gmail → normal browsing
internal ERP → no copy/paste/download/screenshots

3. Browser watermarking
- Prevents screenshots leaking silently.
        username
        IP
        timestamp

4. Shadow IT detection
Detect:
        unknown SaaS
        personal cloud storage
        AI tools
        
Examples:
detects users uploading files to random AI tools

5. GenAI controls
        block prompts containing secrets
        redact sensitive text
        block uploads to AI sites

6. Browser risk scoring
Scores:
        risky extensions
        suspicious domains
        abnormal sessions

7. Device posture enforcement
Checks:
        OS version
        encryption
        antivirus
        MDM presence
        
- before allowing access.


## Unique Features by Vendor
Chrome Enterprise
        best policy ecosystem
        Chrome Browser Cloud Management
        massive policy library (hundreds of policies)

Island Browser
        app-level controls
        browser workflow automation
        per-app policies
        app routing

Netskope Enterprise Browser
        integrated with SSE/SASE stack
        unmanaged device access
        hardened Chromium
        browser impersonation protection
        encrypted assets
        browser + zero trust
        DNS filtering
        secure tunnels


## Open Source Enterprise / Secure Browser Projects

1. Mozilla Firefox + Enterprise Policies
2. “Secure enterprise browser platform”
        Island
        Netskope
        Prisma Browser
        Citrix Enterprise Browser
  
  
## Open-source kiosk browser projects

1. Webview Kiosk [https://github.com/nktnet1/webview-kiosk?utm_source=chatgpt.com]

Features:
        fullscreen
        URL filtering
        lock task mode
        startup lockdown
        
- Android-focused.

2. IMAGINARY kiosk-browser [https://github.com/IMAGINARY/kiosk-browser?utm_source=chatgpt.com]

Features:
        hardened kiosk browser
        fullscreen
        config-driven
        multi-display

- Interesting for digital signage/kiosk scenarios.


## Features You Should Copy for Your Project
- Based on your disposable VM browser project, these are the highest-value enterprise features:

- Must-have
        ephemeral browser profile
        tmpfs user profile
        clear all state on close
        kiosk fullscreen
        disable shortcuts
        disable downloads
        whitelist URLs
        disable devtools
        disable extensions
        disable file dialogs
        block new windows/tabs
        
        per-site policies
        clipboard blocking
        screenshot blocking
        upload/download controls
        session routing
        
        browser profile reset after session
        local logging
        remote config JSON
        admin password unlock
        
        
## Best Open-Source Stack for You

OS
        Alpine Linux or Debian minimal
Browser
        firefox
Hardening
        policies JSON
        launch flags
Session
        tmpfs user profile
        overlayfs reset
UI
        Openbox / Cage / Weston
Startup
        systemd auto-login + browser auto-launch
Security
        disable TTY switching
        disable VT hotkeys
        disable downloads
        disable shell escape


