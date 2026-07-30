# Changelog

All notable changes to the NetBird infrastructure deployment will be documented
in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial documentation structure
- Governance files (CODE_OF_CONDUCT.md, SECURITY.md, CONTRIBUTING.md)
- GitHub and GitLab CI/CD pipelines
- Operations documentation (backup, upgrade, monitoring, troubleshooting)
- Security documentation (hardening, incident response)
- Makefile for operational commands

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
