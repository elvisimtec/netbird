# NetBird Infrastructure

**Self-hosted NetBird deployment for secure private networking.**

Production-grade deployment of [NetBird](https://netbird.io/) — an open-source
VPN and Zero Trust networking platform — running on Hetzner cloud infrastructure
with automatic TLS, reverse proxy, and containerized services.

---

## ⚙️ Settings

> Before working, **read and use the instructions and information in
> [`../Settings/SETTINGS.md`](../Settings/SETTINGS.md)** — access
> credentials and operational guidelines (SSH/SCP, Cloudflare, Docker stacks).

## Architecture

```
                          ┌──────────────────────────┐
                          │     Internet / Clients    │
                          └────────────┬─────────────┘
                                       │
                              Ports 443, 51820/udp
                                       │
                          ┌────────────▼─────────────┐
                          │   Traefik Reverse Proxy   │
                          │   (TLS via Let's Encrypt) │
                          │   netb.koorpa.ba          │
                          └──┬───────┬───────┬───────┘
                             │       │       │
                    ┌────────▼──┐ ┌──▼────┐ ┌▼─────────┐
                    │ Dashboard │ │Server │ │  Proxy   │
                    │   :80     │ │  :80  │ │  :8443   │
                    │  (Web UI) │ │(gRPC/ │ │(WireGuard│
                    │           │ │HTTP/  │ │ passthru)│
                    │           │ │Relay) │ │          │
                    └───────────┘ └───────┘ └──────────┘
                             │
                      ┌──────▼──────┐
                      │   SQLite    │
                      │ (Data Store)│
                      └─────────────┘
                    Internal Docker Network
                        172.30.0.0/24
```

## Components

| Component | Image | Role |
|-----------|-------|------|
| **Traefik v3.6** | `traefik:v3.6` | Reverse proxy, TLS termination (Let's Encrypt), HTTP→HTTPS redirect |
| **NetBird Dashboard** | `netbirdio/dashboard:latest` | Web UI for managing users, peers, and policies |
| **NetBird Server** | `netbirdio/netbird-server:latest` | Management API + Signal + Relay + STUN (combined) |
| **NetBird Proxy** | `netbirdio/reverse-proxy:latest` | WireGuard tunnel endpoint, TCP passthrough |

## Quick Links

- **Dashboard:** [https://netb.koorpa.ba](https://netb.koorpa.ba)
- **Upstream NetBird:** [https://github.com/netbirdio/netbird](https://github.com/netbirdio/netbird)
- **NetBird Docs:** [https://docs.netbird.io](https://docs.netbird.io)

## Server Info

| Property | Value |
|----------|-------|
| **Host** | Hetzner VPS (KVM) |
| **OS** | Ubuntu 24.04.4 LTS |
| **Kernel** | Linux 6.8.0-134-generic |
| **Architecture** | x86-64 |
| **Docker** | 29.6.1 |
| **Docker Compose** | v5.3.1 |
| **Domain** | netb.koorpa.ba |
| **Internal Network** | 172.30.0.0/24 |

## Directory Structure

```
netbird/
├── .github/                    # GitHub templates & CI/CD
│   ├── ISSUE_TEMPLATE/         # Issue forms
│   ├── workflows/              # GitHub Actions
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── .gitlab/                    # GitLab templates & CI/CD
│   ├── issue_templates/
│   └── merge_request_templates/
├── docs/                       # Documentation
│   ├── architecture.md
│   ├── deployment.md
│   ├── configuration.md
│   ├── operations/             # Backup, upgrade, monitoring, troubleshooting
│   └── security/               # Hardening, incident response
├── docker.sh                   # Initial server setup script
├── docker-compose.yml          # Service orchestration
├── config.yaml                 # NetBird server configuration
├── dashboard.env               # Dashboard environment
├── proxy.env                   # Proxy environment
├── traefik-dynamic.yaml        # Traefik dynamic configuration
├── Makefile                    # Operational commands
├── AGENTS.md                   # AI + human governance
├── CONTRIBUTING.md             # Contribution guidelines
├── CODE_OF_CONDUCT.md          # Community standards
├── SECURITY.md                 # Security policy
├── LICENSE                     # MIT License
└── CHANGELOG.md                # Release history
```

## Quick Start

### Prerequisites

- Ubuntu 24.04 LTS server (or 22.04 LTS)
- Public IP address
- Domain name pointed to server IP
- SSH access with key-based authentication

### Initial Server Setup

```bash
# Run the automated setup script as root
sudo bash docker.sh

# The script will:
# 1. Create a user account with sudo + docker group membership
# 2. Install Docker and Docker Compose
# 3. Configure SSH (custom port optional)
```

### Deploy NetBird

```bash
# Clone this repository
git clone https://github.com/elvisimtec/netbird.git /opt/netbird
cd /opt/netbird

# Configure environment files
cp .env.example .env
# Edit .env with your secrets
# Edit dashboard.env and proxy.env with your values

# Deploy all services
make deploy

# Check status
make status
```

## Operational Commands

```bash
make deploy         # Deploy/start all services
make down           # Stop all services
make restart        # Restart all services
make status         # Show service status
make logs           # Tail all logs
make logs-server    # Server logs only
make health-check   # Run health checks
make backup         # Create a backup
make update         # Update all images and restart
make clean          # Stop and remove containers (keeps volumes)
```

## Documentation

- **[Architecture](docs/architecture.md)** — System design and component interactions
- **[Deployment Guide](docs/deployment.md)** — Full deployment walkthrough
- **[Configuration Reference](docs/configuration.md)** — All configuration options
- **[Operations](docs/operations/)** — Backup, upgrade, monitoring, troubleshooting
- **[Security](docs/security/)** — Hardening guide and incident response

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to
this project.

## Security

See [SECURITY.md](SECURITY.md) for our security policy and vulnerability
reporting process.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

NetBird itself is licensed under the [BSD 3-Clause License](https://github.com/netbirdio/netbird/blob/main/LICENSE).
