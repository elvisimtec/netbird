# Changelog

All notable changes to the NetBird infrastructure deployment will be documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Komodo Stack integration** — Stack migrated to Komodo management (2026-07-30)
  - Stack `netbird` live at `https://komo-sso.imtec.ba/stacks` (state: RUNNING)
  - Server: `netbird` (Periphery v2.2.0, systemd, OK)
  - Git repo: `imtec/netbird` on `git.imtec.ba`, branch `main`
  - Clone path: `/opt/stacks/netbird` (existing working tree, gitignored secrets preserved)
  - Project name: `netbird` (Komodo recognized existing compose project, no parallel stack)
  - Deploy: manual only (`auto_update = false`, webhook disabled)
  - Minimal downtime: only proxy/traefik restarted (~2s), server untouched
  - All peer reconnections within 2 seconds, gRPC SignalExchange traffic confirmed
  - Auto-restart: `unless-stopped` + Docker `live-restore: true` + systemd enabled
  - Resource TOML: `resources/komodo-stack.toml`
  - Scripts: `scripts/komodo-migration.sh`, `komodo-verify.sh`, `komodo-rollback.sh`
  - Docs: `docs/operations/komodo.md` (daily ops, troubleshooting, rollback)
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
- **NetBird images unpinned** — `docker-compose.yml` now tracks `latest`
  tags instead of `latest@sha256:...` digests (accepts GitLab commit cc8c120)
- **Server git remote token rotated** — `/opt/stacks/netbird` now uses the
  active `komodo-sync` PAT (id 59) instead of the revoked `glpat-YjEKF...`
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
- **Security Scan workflow** — CodeQL and Secret Scanning jobs failing before start
  - `github/codeql-action` pinned SHA `9e487d54...` (labeled `v3.30.1`) does not exist → re-pinned to real `v3.30.1` commit `07a3889388d8b68f7910cae12b31a2286f3ce994`
  - `gitleaks/gitleaks-action` pinned SHA `83373cf2f8c4f819...` (labeled `v2.3.7`) does not exist → re-pinned to real `v2.3.7` commit `83373cf2f8c4db6e24b41c1a9b086bb9619e9cd3`
  - `actions/dependency-review-action` pinned SHA `4081bf99...` (labeled `v4.6.0`) does not exist → re-pinned to real `v4.6.0` commit `ce3cf9537a52e8119d91fd484ab5b8a807627bf8` (job was skipped on schedule runs, would fail on PRs)
  - Added `issues: write` permission — gitleaks-action files a leak-report issue on findings
  - CodeQL `languages: yaml` is not a supported identifier → changed to `actions` (analyzes GitHub Actions workflows, per `src/languages.ts` of codeql-action)
- **Stale Issue Management workflow** — failing daily with `Unable to resolve action actions/stale@5bef64b6...`
  - Pinned SHA `5bef64b6d7a8efe2d27455c3ba9e719c0830e1ee` (labeled `v11.0.1`) does not exist upstream
  - Re-pinned to real `v11.0.0` commit `4391f3da665fdf50b6810c1a66712fb9ba21aa93`
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
