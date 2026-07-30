# Changelog

All notable changes to the NetBird infrastructure deployment will be documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security
- **UFW firewall activated** — deny incoming, allow only: 2416/tcp, 80/tcp, 443/tcp, 3478/udp, 51820/udp
- **SSH hardened** — `PermitRootLogin prohibit-password`, max 3 tries (password auth retained)
- **Secret scan** — confirmed no secrets in git history
- **Auto-backup** — daily cron @ 02:00 UTC, 7-day retention (store.db, idp.db, configs, certs), 60K compressed
- **Cert monitoring** — daily cron check for Let's Encrypt expiry (45 days, Sep 14)
- **Docker images pinned** — `:latest` tags replaced with `:latest@sha256:...` for controlled upgrades

### Changed
- **NetBird upgraded from v0.74.7 to v0.76.0** (via `:latest`)
  - New: propagated auth grant types for combined server
  - New: unified admin CLI for self-hosted helpers
  - New: dashboard_features and agent_network_only account settings
  - Migration: agent_network_request_usage cost aggregates
  - No breaking changes for self-hosted deployments
- Docker Compose: reverted to `:latest` tags (versioned tags not published on Docker Hub)

### Added
- **Authentik OIDC integration** via Settings → Identity Providers (embedded Dex broker model)
  - Confidential OIDC client with Client Secret (JWS, no encryption)
  - Callback: `https://netb.koorpa.ba/oauth2/callback`
  - Both local and Authentik login available
  - Root cause fix: removed Encryption Key from Authentik provider to use JWS instead of JWE
- Komodo Periphery agent for server management
- Stack database reference documentation
- Relative volume paths for docker-compose

### Changed
- Stack relocated from `/home/netb4521/` to `/opt/stacks/netbird/`
- Docker volumes converted from named volumes to relative bind mounts (`./data/`)
- `docker-compose.yml` and `traefik-dynamic.yaml` added to repository
- `.env.example` updated with Dashboard and Komodo sections

### Security
- SSH key added for `netb4521` user
- NetBird admin user created (`admin@imtec.ba`)
- Authentik OIDC integration attempted → **rolled back** to embedded IdP
  - Root cause: Dex issuer mismatch + public client config incompatible with broker model
  - Rollback: Restored `idp.db`, `config.yaml`, `dashboard.env` from backup
  - Exposed `netbird-svc` App password revoked

### Infrastructure
- NetBird server added to Komodo cluster (Periphery v2.2.0)
- Docker cleanup: 3.4 GB reclaimed from unused images
- Journal log cleanup: 2.3 GB reclaimed, retention set to 7 days

## [1.0.0] - 2025-04-16

### Added
- Initial deployment of NetBird infrastructure
- Traefik v3.6 reverse proxy with Let's Encrypt TLS
- NetBird Server (combined Management + Signal + Relay + STUN)
- NetBird Dashboard web UI
- NetBird Proxy for WireGuard tunnel
- Docker Compose orchestration
- SSH key-based authentication on custom port
- Automated Docker installation script (docker.sh)

### Infrastructure
- **Host:** Hetzner VPS (KVM)
- **OS:** Ubuntu 24.04.4 LTS
- **Domain:** netb.koorpa.ba
- **Network:** 172.30.0.0/24 internal Docker bridge

[Unreleased]: https://github.com/elvisimtec/netbird/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/elvisimtec/netbird/releases/tag/v1.0.0
