cat > user-data <<'EOF'
#cloud-config

hostname: browser-vm

users:
  - name: browser
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false

ssh_pwauth: true
disable_root: false

chpasswd:
  list: |
    browser:browser123
  expire: false

ssh_authorized_keys:
  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPLxzFiNQ96A+Oq+gxS9GznsgiwC0ADbBCaCRtLRqs9Z max@max-HP-EliteBook-Folio-1040-G2

package_update: true

runcmd:
  - systemctl restart ssh

final_message: "Cloud-init setup complete. VM ready."
EOF
