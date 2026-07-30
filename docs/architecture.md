# Architecture

## Overview

The NetBird infrastructure runs on a single Hetzner VPS (KVM) with Ubuntu 24.04 LTS.
All services are containerized using Docker Compose and routed through Traefik
as the reverse proxy.

## System Diagram

```
                          ┌──────────────────────────┐
                          │     Internet / Clients    │
                          └────────────┬─────────────┘
                                       │
                         Ports: 443 (TLS), 51820/udp
                                       │
                          ┌────────────▼─────────────┐
                          │   Traefik Reverse Proxy   │
                          │   v3.6                    │
                          │   - TLS (Let's Encrypt)   │
                          │   - HTTP→HTTPS redirect   │
                          │   - gRPC passthrough      │
                          │   - TCP passthrough       │
                          └──┬───────┬───────┬───────┘
                             │       │       │
                    ┌────────▼──┐ ┌──▼────┐ ┌▼─────────┐
                    │ Dashboard │ │Server │ │  Proxy   │
                    │  :80      │ │  :80  │ │  :8443   │
                    │ (Web UI)  │ │ gRPC  │ │ TCP TLS  │
                    │           │ │ HTTP  │ │ passthru │
                    │           │ │ Relay │ │          │
                    │           │ │ STUN  │ │          │
                    └───────────┘ └──┬────┘ └──────────┘
                                     │
                              ┌──────▼──────┐
                              │   SQLite    │
                              │ /var/lib/   │
                              │  netbird/   │
                              └─────────────┘
                    ┌──────────────────────────────┐
                    │  Internal Docker Network      │
                    │  172.30.0.0/24 (bridge)       │
                    └──────────────────────────────┘
```

## Component Details

### Traefik (netbird-traefik)
- **Image:** `traefik:v3.6`
- **Role:** TLS termination, reverse proxy, HTTP→HTTPS redirect
- **Ports:** 80 (redirects to 443), 443 (TLS)
- **TLS:** Let's Encrypt via `tlsChallenge`, certificate stored in Docker volume
- **Network:** `172.30.0.10` (static IP on internal network)

**Routing Rules:**

| Priority | Router | Rule | Backend |
|----------|--------|------|---------|
| 100 | netbird-grpc | `Host(netb.koorpa.ba) && PathPrefix(/signalexchange..., /management...)` | Server (h2c) |
| 100 | netbird-backend | `Host(netb.koorpa.ba) && PathPrefix(/relay, /ws-proxy, /api, /oauth2)` | Server (HTTP) |
| 1 | netbird-dashboard | `Host(netb.koorpa.ba)` | Dashboard |
| 1 (TCP) | proxy-passthrough | `HostSNI(*)` | Proxy (TLS passthrough) |

The high-priority gRPC and backend routes are matched first. The dashboard
route (priority 1) catches everything else on the domain. The TCP passthrough
rule handles WireGuard tunnel connections.

### NetBird Server (netbird-server)
- **Image:** `netbirdio/netbird-server:latest`
- **Role:** Combined Management + Signal + Relay + STUN
- **Internal Ports:** 80 (HTTP/gRPC), 9000 (health), 9090 (metrics), 3478/udp (STUN)
- **Data:** SQLite at `/var/lib/netbird/store.db`
- **OIDC:** Embedded identity provider at `https://netb.koorpa.ba/oauth2`

**Key Configuration:**
- Auth: PKCE with sign key refresh enabled
- Dashboard redirect URIs: `/nb-auth`, `/nb-silent-auth`
- CLI redirect URI: `http://localhost:53000/`
- Proxy protocol enabled via Traefik trusted proxy

### NetBird Dashboard (netbird-dashboard)
- **Image:** `netbirdio/dashboard:latest`
- **Role:** Web UI for managing NetBird
- **Internal Port:** 80
- **Auth:** OIDC via embedded IdP, client ID `netbird-dashboard`

### NetBird Proxy (netbird-proxy)
- **Image:** `netbirdio/reverse-proxy:latest`
- **Role:** WireGuard tunnel endpoint, exposes internal resources
- **Internal Port:** 8443 (TLS)
- **Published Port:** 51820/udp (WireGuard)
- **TCP Mode:** TLS passthrough through Traefik
- **Proxy Protocol:** v2 enabled (Traefik forwards client IPs)

## Network Architecture

```
External (Internet)
    │
    ├── :443 ──────► Traefik ──► Dashboard / Server
    ├── :51820/udp ─► Proxy (WireGuard tunnel)
    └── :3478/udp ──► Server (STUN — published directly)

Internal Docker Network (172.30.0.0/24)
    ├── 172.30.0.10  — Traefik
    ├── 172.30.0.x   — Dashboard (DHCP)
    ├── 172.30.0.y   — Server (DHCP)
    └── 172.30.0.z   — Proxy (DHCP)
```

- All container-to-container communication happens on the internal bridge network
- Traefik has a static IP for predictable proxy trust configuration
- STUN port (3478/udp) is published directly (bypasses Traefik)
- WireGuard port (51820/udp) is published on the proxy container

## Data Flow

### Agent Connection (gRPC)
```
Agent ──TLS──► Traefik :443 ──h2c──► Server :80
```
Agents connect to `https://netb.koorpa.ba:443` via gRPC. Traefik terminates TLS
and forwards to the server using HTTP/2 cleartext (h2c).

### Dashboard Access (HTTPS)
```
Browser ──TLS──► Traefik :443 ──HTTP──► Dashboard :80
```
Dashboard is a standard web app served over HTTPS.

### WireGuard Tunnel (UDP + TCP TLS)
```
Peer ──UDP──► Proxy :51820/udp  (WireGuard data)
Peer ──TLS──► Traefik :443 ──TCP passthrough──► Proxy :8443 (Control)
```
WireGuard data flows directly via UDP. Control traffic comes through Traefik
as TCP with TLS passthrough (Traefik doesn't terminate — Proxy handles its
own TLS certificates).

## Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `netbird_data` | `/var/lib/netbird` | Server data (SQLite, config) |
| `netbird_traefik_letsencrypt` | `/letsencrypt` | Let's Encrypt certificates |
| `netbird_proxy_certs` | `/certs` | Proxy TLS certificates |

## Logging

All containers use `json-file` driver with rotation:
- Max size: 500 MB per file
- Max files: 2 per service

## System Services

| Service | Purpose |
|---------|---------|
| **UFW** | Host firewall — allows only required ports |
| **fail2ban** | SSH brute-force protection (port 2416) |
| **Cron** | Daily backup (02:00) + cert monitoring (08:00) |
| **Swap** | 2 GB, swappiness=10 |
| **Komodo Periphery** | Server management agent |

## Authentication

| Method | Provider | Status |
|--------|----------|--------|
| **Local login** | Embedded Dex (email/password) | ✅ Active |
| **Authentik OIDC** | `sso.imtec.ba` (Confidential client) | ✅ Active |

Authentik integracija koristi embedded Dex broker model:
`Dashboard → Dex (netb.koorpa.ba/oauth2) → Authentik`

## Docker Hardening

```json
{
  "icc": false,
  "no-new-privileges": true,
  "userland-proxy": false,
  "live-restore": true
}
```

## Backup

- **Skripta:** `/opt/stacks/netbird/backup.sh`
- **Cron:** daily @ 02:00 UTC
- **Retencija:** 7 dana
- **Sadržaj:** `store.db`, `idp.db`, configs, certs
- **Log:** `/var/log/netbird-backup.log`

## Cert Monitoring

- **Skripta:** `/opt/stacks/netbird/check-cert.sh`
- **Cron:** daily @ 08:00 UTC
- **Log:** `/var/log/cert-check.log`

## Management

### Komodo Periphery

Server je dodat u Komodo klaster za centralizovano upravljanje i monitoring.

| Property | Value |
|----------|-------|
| **Core URL** | `https://komo-sso.imtec.ba` |
| **Server Name** | `netbird` |
| **Agent** | Komodo Periphery v2.2.0 |
| **Service** | `periphery.service` (systemd, auto-start) |
| **Config** | `/etc/komodo/periphery.config.toml` |
| **Keys** | `/etc/komodo/keys/` (periphery.key, periphery.pub, core.pub) |
| **Port** | 8120 (inbound, SSL enabled) |
| **Connection** | Outbound WebSocket → `wss://komo-sso.imtec.ba/ws/periphery` |

```bash
# Status
systemctl status periphery

# Logs
journalctl -u periphery -f

# Restart
systemctl restart periphery
```
