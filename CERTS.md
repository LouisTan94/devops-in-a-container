# TLS Certificates Walkthrough

Self-signed cert setup for the Nexus nginx reverse proxy, covering generation,
trust, and common errors.

---

## How It Works

```
rootCA.key + rootCA.crt   ← your own Certificate Authority
       │
       └─ signs ──► nexus.key + nexus.crt   ← served by nginx
```

- **rootCA.crt** — must be trusted by every OS/browser/Docker that connects
- **nexus.crt** — the actual TLS cert nginx presents on ports 443, 5000, 5001
- The cert covers multiple names/IPs via Subject Alternative Names (SAN)

---

## Generating Certs

Run from the project root in Git Bash:

```bash
# Auto-detect local IP
./generate-certs.sh

# Or pass your LAN IP explicitly (recommended on Windows with many virtual adapters)
./generate-certs.sh 192.168.6.133
```

### What it produces

```
nginx/certs/
  rootCA.key    ← keep private, never share
  rootCA.crt    ← distribute to clients that need to trust the registry
  nexus.key     ← nginx private key
  nexus.crt     ← nginx certificate (signed by rootCA)
  nexus.csr     ← certificate signing request (intermediate, can ignore)
  nexus.ext     ← SAN config used during signing
  rootCA.srl    ← serial number tracker (auto-managed)
```

### Verify the cert SANs

```cmd
openssl x509 -in nginx\certs\nexus.crt -noout -text | findstr "DNS IP"
```

Expected output:
```
DNS:localhost, DNS:dep-pipeline-nexus, DNS:IG06, DNS:IG06.local, IP Address:127.0.0.1, IP Address:192.168.6.133
```

---

## Trusting the Root CA

This must be done on **every machine** that connects to the registry,
including the machine running the stack. Redo this step any time you
regenerate certs (a new rootCA is created each run).

### Windows (browser + Docker Desktop)

1. Double-click `nginx\certs\rootCA.crt`
2. Click **Install Certificate**
3. Select **Local Machine** → Next
4. Select **Place all certificates in the following store** → Browse →
   **Trusted Root Certification Authorities**
5. Finish → Yes to the security prompt
6. **Restart Docker Desktop** — required, Docker won't pick it up otherwise

### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain rootCA.crt
```

Restart browser and Docker Desktop.

### Linux

```bash
# Ubuntu/Debian
sudo cp nginx/certs/rootCA.crt /usr/local/share/ca-certificates/dep-pipeline.crt
sudo update-ca-certificates

# RHEL/Fedora/CentOS
sudo cp nginx/certs/rootCA.crt /etc/pki/ca-trust/source/anchors/dep-pipeline.crt
sudo update-ca-trust

sudo systemctl restart docker
```

### Docker daemon on another machine (for registry access)

```bash
sudo mkdir -p /etc/docker/certs.d/IG06.local:5001
sudo cp rootCA.crt /etc/docker/certs.d/IG06.local:5001/ca.crt

sudo mkdir -p /etc/docker/certs.d/IG06.local:5000
sudo cp rootCA.crt /etc/docker/certs.d/IG06.local:5000/ca.crt

sudo systemctl restart docker
```

---

## Applying New Certs to Nginx

After any regeneration, restart nginx to load the new cert:

```bash
docker compose restart nginx
```

Confirm nginx is serving the new cert (not the old one):

```cmd
echo | openssl s_client -connect localhost:443 2>NUL | openssl x509 -noout -subject
```

Expected: `subject=C=XX, ST=Local, L=Local, O=dep-pipeline, CN=localhost`

---

## When to Regenerate

| Situation | Action |
|-----------|--------|
| First setup | Run once |
| Machine IP changed | `./generate-certs.sh <new-ip>` |
| Cert expired (825 days) | Re-run script |
| Added a new hostname/IP | Re-run script |
| After regenerating, always | Re-trust rootCA.crt + restart Docker Desktop |

---

## Accessing the Registry

| From | Use |
|------|-----|
| Same machine | `localhost:5001` or `192.168.6.133:5001` |
| LAN (mDNS) | `IG06.local:5001` |
| Inside Docker network | `dep-pipeline-nexus:5001` (no TLS needed) |

```bash
docker login IG06.local:5001
docker login 192.168.6.133:5001
docker push 192.168.6.133:5001/my-image:tag
```

---

## Troubleshooting

### `x509: certificate is valid for X, not 192.168.6.x`

The cert's SAN does not include the IP you're connecting to.

```bash
# Check what the cert currently covers
openssl x509 -in nginx\certs\nexus.crt -noout -text | findstr "DNS IP"

# Regenerate with the correct IP
./generate-certs.sh 192.168.6.133
docker compose restart nginx
```

Re-trust rootCA.crt and restart Docker Desktop.

---

### `x509: certificate signed by unknown authority`

The rootCA is not trusted on this machine, or the certs were regenerated
and the old trusted CA is now stale.

- Re-install `rootCA.crt` to Trusted Root Certification Authorities
- Restart Docker Desktop

---

### `http: server gave HTTP response to HTTPS client`

You're connecting to a plain HTTP port with a Docker/TLS client.

- Port 8081 → Nexus web UI (HTTP only, not a Docker registry)
- Port 5000 / 5001 → Docker registry (HTTPS via nginx)

Use port `5001` for docker login/push/pull.

---

### `IG06.local` not resolving

mDNS may not be available on the client machine.

Add an entry to the hosts file instead:

- **Windows**: `C:\Windows\System32\drivers\etc\hosts` (open Notepad as admin)
- **Linux/macOS**: `/etc/hosts`

```
192.168.6.133    IG06.local
```

---

### IP auto-detection picks up wrong adapter (Windows)

Windows has many virtual adapters (Docker, WSL, Hyper-V). The script may
detect a virtual IP like `172.x.x.x` or `192.168.57.x` instead of your
real LAN IP.

Always pass the IP explicitly on Windows:

```bash
./generate-certs.sh 192.168.6.133
```

Find your real LAN IP with:

```cmd
ipconfig
```

Look for the adapter with a **Default Gateway** set — that is your LAN adapter.
