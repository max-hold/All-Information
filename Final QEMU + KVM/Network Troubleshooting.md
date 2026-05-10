# Network Troubleshooting

## Find your subnet
```
ip a
```
### Expected Output:
```
192.168.100.x/24
```

## Check which one has SSH (port 22)
```
nmap -p 22 --open 192.168.100.0/24
```
### Expected Output:
```
192.168.100.42  open  ssh
```

## Check your hypervisor
```
virsh list
virsh domifaddr <vm-name>
```
### Expected Output:
```
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------

```
- If you see this, Your VM does not have an IP via DHCP.

## Check VM network type
```
virsh domiflist browser-template-2
```
### Expected Output:
```
network default
or bridge br0
or virbr0
```

## Check if default network is running
```
virsh net-list --all
```
### Expected Output:
```
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
```
- If default or active is missing
```
sudo virsh net-define /dev/stdin <<'EOF'
<network>
  <name>default</name>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
  <nat>
    <port start='1024' end='65535'/>
  </nat>
</network>
EOF

sudo virsh net-start default
sudo virsh net-autostart default
```
### Expected Output:
```
Network default defined from /dev/stdin
Network default started
Network default marked as autostarted
``` 

## run the default network
```
virsh net-start default
virsh net-autostart default
```

## Restart the VM
```
virsh reboot browser-template-2
```




## If still no IP (very common)
- No DHCP request Or broken network config inside VM
### Then inside VM:
```
ip a
dhclient

virsh net-dhcp-leases default
```
### Expected Output:
```
192.168.122.x
```

## But KVM default network is usually run in `192.168.122.0/24`:
```
nmap -p 22 --open 192.168.122.0/24
```




## Assign IP manually inside VM
```
virsh console browser-template-2
```
## Then inside VM:
```
ip a
```
### Expected Output:
```
 eth0 or ens3 with no IP.
```

## Assign static IP:
```
sudo ip addr add 192.168.100.42/24 dev eth0
sudo ip link set eth0 up
```
- (Replace eth0 with your interface name if needed)

## Test from host:
```
ping 192.168.100.42
ssh browser@192.168.100.42
```




## Add DHCP

You have two clean choices:

🔹 Option A: Use libvirt default network (recommended)

Instead of br-vm, switch VM to:

network: default (virbr0)

Then:

virsh net-start default
virsh reboot browser-template-2

Now your VM will get:

192.168.122.x automatically
🔹 Option B: Add DHCP to br-vm (advanced)

You’d need something like:

dnsmasq
or router bridge integration

(Only do this if you really need custom bridging)

🧠 Why your scan failed (important insight)

Your scan was correct:

nmap 192.168.100.0/24

But:

🔴 There are zero devices with IPs in that network

So nothing responded.

⚡ Quickest working solution

Do this right now:

virsh console browser-template-2

Then inside VM:

sudo ip addr add 192.168.100.42/24 dev eth0
sudo ip link set eth0 up

Then from host:

ssh browser@192.168.100.42
🚀 Pro tip (to avoid this forever)

When creating VMs:

Use NAT (default network) unless you specifically need bridging
Bridging requires:
DHCP OR
manual IP management

If you want, I can help you:



Just tell me 👍
