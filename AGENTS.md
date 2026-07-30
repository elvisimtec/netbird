# AGENTS.md — NetBird Infrastructure Governance

This file serves as the canonical development and operations guide for both
human contributors and AI coding assistants working on the NetBird
infrastructure project.

---

## Project Identity

- **Project:** NetBird Infrastructure — self-hosted secure private networking
- **Repository:** `elvisimtec/netbird`
- **Infrastructure:** Hetzner VPS, Ubuntu 24.04 LTS, Docker Compose
- **Stack Path:** `/opt/stacks/netbird/`
- **Domain:** `netb.koorpa.ba`
- **License:** MIT
- **Upstream:** [netbirdio/netbird](https://github.com/netbirdio/netbird) (BSD 3-Clause)

---

## What We Want (Contribution Priorities)

Ranked in order of importance. Higher-ranked items get faster review and higher
priority:

1. **Bug fixes** — Especially for deployment issues, configuration errors,
   service downtime, or security problems.
2. **Security hardening** — Firewall rules, secret rotation, TLS configuration,
   container security improvements.
3. **Documentation improvements** — Clear, actionable docs that help operators
   deploy and maintain NetBird.
4. **Operational tooling** — Makefile targets, monitoring scripts, health checks,
   backup automation.
5. **Configuration improvements** — Better defaults, performance tuning,
   resource optimization.
6. **New integrations** — Monitoring (Prometheus/Grafana), logging aggregation,
   alerting — but these should be standalone additions, not changes to core config.

## What We DON'T Want

- **Upstream feature modifications** — We deploy NetBird, we don't fork it.
  Changes to NetBird itself should go to [netbirdio/netbird](https://github.com/netbirdio/netbird).
- **Breaking configuration changes** — Changes that require manual migration on
  the production server must be clearly documented and gated behind a major
  version bump.
- **Untested deployment changes** — Any change to docker-compose.yml, config.yaml,
  or environment files MUST be tested or explicitly marked as untested.
- **Hardcoded secrets** — Never commit secrets. Use `.env` files (git-ignored).
- **Over-engineering** — Keep it simple. This is an infrastructure deployment,
  not a platform. Prefer simplicity over abstraction.

## The Footprint Ladder

When adding a new capability, use this decision tree (in priority order):

1. **Document it** — Most needs can be solved with better docs or scripts.
2. **Add a Makefile target** — If it's a repeatable operational task.
3. **Add a shell script** — If it needs more logic than a one-liner.
4. **Add a new service to docker-compose** — Only if it provides clear value
   (monitoring, alerting, log aggregation).
5. **Modify core configuration** — Last resort, needs strong justification.

## Project Structure

```
netbird/
├── .github/                    # GitHub-specific: CI/CD, templates
│   ├── ISSUE_TEMPLATE/         # Bug, feature, docs issue forms
│   ├── workflows/              # GitHub Actions pipelines
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── .gitlab/                    # GitLab-specific: CI/CD, templates
├── docs/                       # All documentation
│   ├── architecture.md         # System design
│   ├── deployment.md           # How to deploy
│   ├── configuration.md        # Config reference
│   ├── operations/             # Backup, upgrade, monitoring, troubleshooting
│   └── security/               # Hardening, incident response
├── docker-compose.yml          # PRIMARY — the deployment manifest (in repo)
├── traefik-dynamic.yaml        # Traefik dynamic config (in repo)
├── Makefile                    # Operational commands
├── AGENTS.md                   # THIS FILE — governance
├── CONTRIBUTING.md             # How to contribute
├── CODE_OF_CONDUCT.md          # Community standards
├── SECURITY.md                 # Security policy
├── LICENSE                     # MIT
├── CHANGELOG.md                # Release history
├── .gitignore
└── .env.example                # Template (no secrets)

# On server only (secrets — gitignored):
#   config.yaml, dashboard.env, proxy.env, docker.sh, .env
#   data/ (Docker volume data — gitignored)
```

### Key File Purposes

| File | Location | Purpose | When to Modify |
|------|----------|---------|----------------|
| `docker-compose.yml` | **Repo + Server** | Service definitions, networks, volumes | Adding services, changing ports, updating images |
| `traefik-dynamic.yaml` | **Repo + Server** | Traefik TCP-level settings | Changing proxy protocol settings |
| `config.yaml` | Server only | NetBird server runtime config | Changing auth, store, server settings |
| `dashboard.env` | Server only | Dashboard OIDC and endpoint config | Changing domain, OIDC settings |
| `proxy.env` | Server only | Proxy connection and TLS settings | Changing proxy token, domain |
| `Makefile` | Repo | Operational convenience commands | Adding new operational tasks |
| `docker.sh` | Server only | First-time server setup | Changing Docker install process |
| `data/` | Server only | Docker volume data (gitignored) | Never — managed by Docker |

---

## Development Workflow

### Making Changes

1. **Branch from `main`** — Never commit directly to `main`.
   ```bash
   git checkout -b feature/description
   ```

2. **Test locally if possible** — Docker Compose changes can be validated locally:
   ```bash
   docker compose config  # Validate compose file
   docker compose up -d   # Test deployment (local Docker)
   ```

3. **Deploy to staging first** — If you have a staging server, deploy there first.

4. **Update documentation** — If your change affects behavior, update relevant
   docs in `docs/`.

5. **Update CHANGELOG.md** — Add an entry under `[Unreleased]`.

### Commit Conventions

Use conventional commits for clear history:

```
feat: add Prometheus monitoring stack
fix: correct proxy TLS passthrough routing
docs: update backup procedure for SQLite
ops: add health-check Makefile target
security: rotate proxy token
chore: update Traefik to v3.7
```

### PR Checklist

Before opening a PR, verify:

- [ ] Changes are on a feature branch (not `main`)
- [ ] `docker compose config` passes (if compose file changed)
- [ ] Documentation is updated in `docs/`
- [ ] CHANGELOG.md has an `[Unreleased]` entry
- [ ] No secrets are committed (check with `git diff --cached`)
- [ ] `.env.example` is updated if new variables were added
- [ ] The change follows the Footprint Ladder

---

## Server Connection

The production server is accessed via SSH. Connection details are in `.env`
(git-ignored).

### Makefile targets handle server connectivity:

```bash
make ssh            # Connect to server via SSH
make deploy         # Deploy docker-compose on server
make status         # Show service status
make logs           # Tail all logs
make update         # Pull + restart services
make backup         # Create backup of volumes and config
```

### Direct SSH (when Makefile doesn't cover it):

```bash
# Using SSH config style (if ~/.ssh/config has Host netbird defined)
ssh netbird

# Direct command
ssh -i C:/Users/elvis.crnic/.ssh/netbird -p 2416 root@46.225.130.12
```

---

## Known Pitfalls

### 1. Never commit `.env` files
The `.env` file contains SSH keys and sudo passwords. It is git-ignored.
Always use `.env.example` as a template.

### 2. Proxy token rotation breaks connections
If you rotate `NB_PROXY_TOKEN` in `proxy.env`, all connected peers will
disconnect. Plan a maintenance window and notify users.

### 3. Let's Encrypt rate limits
Traefik manages Let's Encrypt certificates automatically. There are rate
limits (50 certificates per domain per week). Don't repeatedly restart
Traefik in quick succession.

### 4. Docker image tags
`docker-compose.yml` uses `:latest@sha256:...` pinned digests for NetBird images
and `traefik:v3.6` pinned version. Upgrading requires updating digests manually.
Check release notes before upgrading.

### 5. Firewall rules
The server has UFW active with only required ports: 80, 443, 2416/tcp, 3478/udp,
51820/udp. For full protection also configure **Hetzner Cloud Firewall** (blocks
Docker-published ports that bypass UFW). Adding new exposed ports must be
intentional and documented.

### 6. SQLite database
NetBird uses SQLite as the data store. This is fine for single-server deployment
but has limitations:
- No high availability (single writer)
- Backup must use `sqlite3 .backup` or copy the file when no writes are happening
- Consider migrating to PostgreSQL for multi-server setups

### 7. SSH configuration
The server uses a non-standard SSH port (2416) with key-based authentication.
`PermitRootLogin prohibit-password` and `MaxAuthTries 3` are set.
Password authentication is currently enabled. Lost SSH keys mean lost access.

### 8. Anonymous metrics
Anonymous metrics are **disabled** via `--disable-anonymous-metrics` flag.
To re-enable, remove the flag from docker-compose.yml server command.

### 9. Authentik OIDC integration
Authentik is configured as an external IdP through Dashboard → Settings → Identity Providers.
Uses Confidential OIDC client with embedded Dex broker model (`Dashboard → Dex → Authentik`).
- Callback: `https://netb.koorpa.ba/oauth2/callback`
- Never edit `idp.db` connector table directly
- Never change the Dex issuer from `https://netb.koorpa.ba/oauth2`
- Authentik provider MUST have Encryption Key empty (JWS only, not JWE)

---

## Configuration Patterns

### Adding a new environment variable

1. Add it to the relevant `.env` file on the server
2. Reference it in `docker-compose.yml` under the appropriate service
3. Add it to `.env.example` (with placeholder value)
4. Document it in `docs/configuration.md`
5. Update CHANGELOG.md

### Adding a new service

1. Add the service definition to `docker-compose.yml`
2. Connect it to the `netbird` network
3. Add Traefik labels if it needs HTTP/HTTPS exposure
4. Add relevant environment files
5. Create documentation in `docs/`
6. Update `README.md` architecture diagram
7. Add Makefile targets if needed
8. Update CHANGELOG.md

### Modifying existing configuration

1. Understand the current behavior first (`git log -p -- <file>`)
2. Make the change on a feature branch
3. Validate with `docker compose config`
4. Document the change and migration steps (if any)
5. Test on the server during a maintenance window (if risky)

---

## Testing

### Local validation

```bash
# Validate Docker Compose syntax
docker compose config --quiet

# Validate YAML files
yamllint docker-compose.yml config.yaml

# Check for secrets in staged files
git diff --cached --name-only | xargs grep -l 'NB_PROXY_TOKEN\|authSecret\|encryptionKey' || echo "No secrets found"
```

### Server testing

```bash
# Check service health
docker compose ps

# Check NetBird server health
curl -s http://localhost:9000/health

# Test Dashboard accessibility
curl -s -o /dev/null -w "%{http_code}" https://netb.koorpa.ba

# Check gRPC connectivity
# (requires netbird client or grpcurl)
```

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (`X.0.0`): Breaking configuration changes, major architecture shifts
- **MINOR** (`0.X.0`): New services, new Makefile targets, significant doc updates
- **PATCH** (`0.0.X`): Bug fixes, doc corrections, dependency updates

Version tags track the infrastructure configuration, not the NetBird version.
NetBird component versions are tracked separately in the CHANGELOG.

---

## Related Repositories

- **Upstream NetBird:** [github.com/netbirdio/netbird](https://github.com/netbirdio/netbird)
- **GitLab Mirror:** `elvisimtec/netbird` (GitLab)
- **Komodo:** `https://komo-sso.imtec.ba` — server management & monitoring
