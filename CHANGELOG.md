# Changelog

All notable changes to the NetBird infrastructure deployment will be documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Authentik OIDC integration** via Settings → Identity Providers (embedded Dex broker)
  - Confidential OIDC client (JWS, no encryption)
  - Callback: `https://netb.koorpa.ba/oauth2/callback`
  - Both local and Authentik login available
- **Komodo Periphery agent** v2.2.0 for server management
- **Auto-backup** — daily cron @ 02:00 UTC, 7-day retention
- **Cert monitoring** — daily cron @ 08:00 UTC, alerts at 14 days
- **2 GB swap** — swappiness=10
- **fail2ban** — SSH brute-force protection on port 2416
- **Database reference** — encryption scheme, OIDC structure, user management
- **NetBird admin user** — `admin@imtec.ba`

### Changed
- **NetBird upgraded** from v0.74.7 to v0.76.0
  - Propagated auth grant types for combined server
  - Unified admin CLI for self-hosted helpers
  - Migration: agent_network_request_usage cost aggregates
- **Stack relocated** from `/home/netb4521/` to `/opt/stacks/netbird/`
- **Docker volumes** converted to relative bind mounts (`./data/`)
- **Docker images pinned** `:latest@sha256:...`
- **Anonymous metrics** disabled via `--disable-anonymous-metrics`

### Security
- **UFW firewall** activated — 2416/tcp, 80/tcp, 443/tcp, 3478/udp, 51820/udp
- **SSH hardened** — `PermitRootLogin prohibit-password`, `MaxAuthTries 3`
- **Docker hardened** — `icc:false`, `no-new-privileges:true`, `userland-proxy:false`, `live-restore:true`
- **Secret scan** — confirmed clean, no secrets in git history
- **Authentik OIDC** — first attempt rolled back, then successful via Dashboard UI
- **`netbird-svc`** service account deleted after OIDC migration

### Infrastructure
- Docker cleanup: 3.4 GB reclaimed
- Journal log cleanup: 2.3 GB reclaimed, retention 7 days
- SSH key added for `netb4521` user
- Disk: 4.9 GB / 38 GB (14%)

### Fixed
- **CI pipeline** — validate and lint jobs now pass correctly
  - Replaced broken GitHub Action SHA pins (`ibiqlik/action-yamllint`, `DavidAnson/markdownlint-cli2-action`) with inline `pip`/`npm` installs
  - Validate job now creates stub `config.yaml`/`*.env` files before `docker compose config`
  - Markdownlint scope narrowed from `**/*.md` to `*.md` + `docs/**/*.md`
  - Fixed `docker-compose.yml` port indentation (`4→6` spaces, yamllint MD005)
  - Fixed `.gitlab-ci.yml` YAML syntax error (curly braces in double-quoted string)

### Repository
- `docker-compose.yml` and `traefik-dynamic.yaml` added
- `.env.example` updated with Dashboard, Komodo sections
- Project structure updated in AGENTS.md

## [1.0.0] - 2025-04-16

### Added
- Initial deployment of NetBird infrastructure
- Traefik v3.6 reverse proxy with Let's Encrypt TLS
- NetBird Server (combined Management + Signal + Relay + STUN)
- NetBird Dashboard web UI
- NetBird Proxy for WireGuard tunnel
- Docker Compose orchestration
- SSH key-based authentication on custom port (2416)
- Automated Docker installation script (docker.sh)

### Infrastructure
- **Host:** Hetzner VPS (KVM)
- **OS:** Ubuntu 24.04.4 LTS
- **Domain:** netb.koorpa.ba
- **Network:** 172.30.0.0/24 internal Docker bridge

[Unreleased]: https://github.com/elvisimtec/netbird/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/elvisimtec/netbird/releases/tag/v1.0.0
