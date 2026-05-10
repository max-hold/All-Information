- Hard kill any shell spawn
```
nano /usr/local/bin/kill-shell.sh
```
```
#!/bin/sh
pkill -9 sh
pkill -9 bash
pkill -9 ash
pkill -9 tty
pkill -9 login
```
```
chmod +x /usr/local/bin/kill-shell.sh
```
```
nano /etc/local.d/kill-shell.start
```
```
#!/bin/sh
while true; do
    /usr/local/bin/kill-shell.sh
    sleep 1
done
```
```
chmod +x /etc/local.d/kill-shell.start
rc-update add local
```

- Network Lockdown (Only Firefox allowed)
```
# Create network lockdown service (OpenRC)
cat > /etc/init.d/kiosk-netlock << 'EOF'
#!/sbin/openrc-run
name="kiosk-netlock"
description="Allow ONLY Firefox network traffic"

start() {
    ebegin "Applying kiosk network lockdown (only Firefox + web ports)"
    # Allow loopback + established
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow only processes in kiosknet group (Firefox will run in this group)
    iptables -A OUTPUT -m owner --gid-owner kiosknet -j ACCEPT

    # DNS + HTTP/HTTPS (fallback safety)
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

    eend $?
}

stop() {
    iptables -P OUTPUT ACCEPT
}
EOF

chmod +x /etc/init.d/kiosk-netlock
rc-update add kiosk-netlock default
rc-service kiosk-netlock start
```

- Lock Root & Privileges
```
passwd -l root
apk del sudo && doas
rm -f /bin/su /usr/bin/su 2>/dev/null || true
chmod 000 /bin/su
```

- NETWORK LOCK: Only Firefox Can Use Internet
- the best way to do it is QEMU networking with restricted mode
- but we can do it inside the Vm
```
# Step 1: get Firefox UID
id browser-vm

# Step 2: add iptables
apk add iptables

# Step 3: iptables rules
nano /etc/local.d/firewall.start

#!/bin/sh
iptables -P OUTPUT DROP
iptables -A OUTPUT -m owner --uid-owner 1000 -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

chmod +x /etc/local.d/firewall.start

```

- Host-enforced network kill switch
```
# Do NOT trust guest firewall alone.
# On host, isolate VM process.
# Run QEMU under dedicated UID:

sudo useradd vmnet

# Then firewall:

sudo iptables -A OUTPUT -m owner ! --uid-owner vmnet -j DROP

# That’s too aggressive globally, so better with dedicated namespace.
# Use Linux network namespace:

ip netns add kioskns

# Move VM tap into it.
# Only allow outbound HTTP/HTTPS from namespace.
```

- Disable Downloads (Controlled Toggle)
```
# Anything downloaded to that Downloads folder lives only in memory — fast, but disappears on reboot
# This command is typically used for security / privacy reasons
mount -t tmpfs -o size=1M tmpfs /home/browser-vm/Downloads
# Then it is completely locked down — no one can easily read or write to it.
chmod 000 /home/browser-vm/Downloads
```

- Controlled PIPELINE (VM ↔ HOST)
```
# Use Virtio-Serial (safe channel) / Add QEMU Run command
-chardev socket,id=pipe0,path=/tmp/vm-pipe.sock,server=on,wait=off \
-device virtio-serial \
-device virtserialport,chardev=pipe0,name=vmchannel

# Inside VM (Python sender)
import os
PIPE = "/dev/virtio-ports/vmchannel"
def send_file(path):
    with open(path, "rb") as f, open(PIPE, "wb") as pipe:
        pipe.write(f.read())
send_file("/home/browser-vm/Downloads/file.txt")

# Host receiver
nc -lU /tmp/vm-pipe.sock > received_file
```

- Remove package manager from guest
```
chmod 000 /sbin/apk
rm -rf /sbin/apk
rm -rf /etc/apk
rm -rf /lib/apk
rm -rf /usr/share/apk
rm -rf /var/lib/apk
```

- Remove compilers/interpreters
```
apk del python3 gcc g++ make perl
```

- Kernel hardening inside guest
```
apk add linux-hardened

sysctl -w kernel.kptr_restrict=2
sysctl -w kernel.dmesg_restrict=1
sysctl -w kernel.unprivileged_userns_clone=0
sysctl -w fs.protected_symlinks=1
sysctl -w fs.protected_hardlinks=1

# Persist in:
/etc/sysctl.conf
```

- Disable ptrace / Blocks process inspection.
```
sysctl -w kernel.yama.ptrace_scope=3
```



# Run Firefox inside another sandbox (nested containment)

Don’t trust Firefox even inside VM.

Install:

apk add bubblewrap

Launch Firefox like:

bwrap \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --tmpfs /tmp \
  --dir /home/browser-vm \
  --unshare-all \
  --share-net \
  firefox --kiosk https://example.com

This gives Firefox its own namespace jail.

Even if Firefox gets compromised:

harder lateral movement
filesystem limited
