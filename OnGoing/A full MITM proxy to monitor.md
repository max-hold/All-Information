# A full MITM proxy to monitor and control 
- first: modern HTTPS traffic is encrypted, so to inspect content you need the browser in your VM to trust your own proxy certificate. Otherwise you’ll only see domains and connection metadata.

## Install MITM proxy on host
```
# === RUN ON HOST ===
sudo apt update
sudo apt install python3-pip -y
pip install mitmproxy --break-system-packages
```
```
# === RUN ON HOST ===
mitmweb --listen-host 0.0.0.0 --listen-port 8080

# This gives:
# proxy on port 8080
# web dashboard usually on 127.0.0.1:8081
```

## Force VM Firefox through proxy
```
# === RUN INSIDE VM ===
nano /usr/lib/firefox/distribution/policies.json

{
  "policies": {
    "Proxy": {
      "Mode": "manual",
      "HTTPProxy": "10.0.2.2:8080",
      "SSLProxy": "10.0.2.2:8080",
      "UseHTTPProxyForAllProtocols": true,
      "Locked": true
    },
    "DisableNetworkPrediction": true
  }
}
```

## Install proxy CA certificate into Firefox
```
# === RUN ON HOST (first time) ===
# Start MITM once
mitmproxy

# It creates certs in:
cd ~/.mitmproxy/

# You’ll see
mitmproxy-ca-cert.pem

# send the mitmproxy-ca-cert.pem to the vm
python3 -m http.server 9000
```
```
# === RUN INSIDE VM ===
wget http://10.0.2.2:9000/mitmproxy-ca-cert.pem

# add the nss
apk add nss-tools

# First find the profile:
ls ~/.mozilla/firefox/

# find the mitmproxy  file
# You should see something like: " /home/browser-vm/mitmproxy-ca-cert.pem "
find / -name "*mitmproxy*" 2>/dev/null

# Verify import worked
certutil -L -d sql:$HOME/.mozilla/firefox/< 1ekwhg67.default-release >

certutil -A \
  -n "MITMProxy" \
  -t "C,," \
  -i /home/browser-vm/mitmproxy-ca-cert.pem \
  -d sql:$HOME/.mozilla/firefox/< 1ekwhg67.default-release >
```

## Block direct internet bypass
```
# === RUN INSIDE VM ===
iptables -P OUTPUT DROP
iptables -A OUTPUT -d 10.0.2.2 -p tcp --dport 8080 -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

## Check the proxy 
```
# Can you reach the proxy port?
nc -zv 10.0.2.2 8080

# Test basic HTTP through proxy
http_proxy=http://10.0.2.2:8080 wget -qO- http://example.com || echo "Failed"
```

## Log everything
```
# === RUN ON HOST ===
mitmproxy -w traffic.mitm

# to view later
mitmproxy -r traffic.mitm
```

## Block downloads / file types
- First create the script block_downloads.py on the host, then:
```
# === RUN ON HOST ===
nano block_downloads.py

# add to the file
from mitmproxy import http
BLOCK_EXT = [".exe", ".zip", ".apk", ".sh", ".deb"]
def request(flow: http.HTTPFlow):
    url = flow.request.pretty_url.lower()
    for ext in BLOCK_EXT:
        if url.endswith(ext):
            flow.response = http.Response.make(
                403,
                b"Blocked by kiosk proxy",
                {"Content-Type": "text/plain"},
            )

# run it
mitmproxy -s block_downloads.py
```

## Domain allowlist
- Create the script on the host, then run:
```
# === RUN ON HOST ===
nano your_allowlist_script.py

# add to the file 
from mitmproxy import http
ALLOWED = [
    "google.com",
    "wikipedia.org"
]
def request(flow: http.HTTPFlow):
    host = flow.request.host
    if not any(domain in host for domain in ALLOWED):
        flow.response = http.Response.make(
            403,
            b"Blocked domain",
            {"Content-Type": "text/plain"}
        )
# Run
mitmproxy -s your_allowlist_script.py
```

## Monitor live browser traffic
```# === RUN ON HOST ===
mitmweb
# open on the host browser
http://127.0.0.1:8081
```

## DNS enforcement
```
# === RUN INSIDE VM ===
echo "nameserver 10.0.2.2" > /etc/resolv.conf
```

## Final launch flow
```
# === RUN ON HOST ===
mitmweb --listen-port 8080
(Then start your VM)
```

