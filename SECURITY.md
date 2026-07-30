# Security Policy

## Reporting a Vulnerability

The NetBird infrastructure team takes security seriously. If you discover a
security vulnerability, we appreciate your help in disclosing it responsibly.

### How to Report

**Do NOT open a public issue.** Instead, report vulnerabilities privately:

- **Email:** [INSERT SECURITY EMAIL]
- **GitHub Security Advisory:** Use the "Report a vulnerability" button on the
  [Security tab](https://github.com/elvisimtec/netbird/security/advisories)

Please include as much information as possible:

- Type of vulnerability
- Steps to reproduce or proof-of-concept
- Affected component(s) and version(s)
- Potential impact
- Suggested fix (if any)

### What to Expect

1. **Acknowledgment:** Within 48 hours, we will acknowledge receipt.
2. **Triage:** Within 5 business days, we will confirm the vulnerability and
   determine severity.
3. **Resolution:** We will work on a fix and keep you updated on progress.
4. **Disclosure:** We coordinate public disclosure with you. By default, we
   target a 90-day disclosure window.

We do not currently offer monetary bounties, but we publicly acknowledge
reporters in our security advisories (unless you prefer to remain anonymous).

## Supported Configurations

| Component | Version | Supported |
|-----------|---------|-----------|
| NetBird Server | latest (Docker) | ✅ |
| NetBird Dashboard | latest (Docker) | ✅ |
| NetBird Proxy | latest (Docker) | ✅ |
| Traefik | v3.x | ✅ |
| Docker Engine | 24+ | ✅ |
| Docker Compose | v2+ | ✅ |
| Ubuntu Server | 24.04 LTS | ✅ |
| Ubuntu Server | 22.04 LTS | ✅ |

## Security Model

### Trust Boundaries

This deployment uses a defense-in-depth approach:

```
Internet
  │
  ▼
[Traefik Reverse Proxy]  ← TLS termination, Let's Encrypt
  │
  ├──► [Dashboard]       ← Web UI (authenticated)
  ├──► [Server: gRPC]    ← Agent communication (mutual TLS)
  ├──► [Server: HTTP]    ← API, OAuth2, WebSocket, Relay
  └──► [Proxy: TCP]      ← WireGuard tunnel passthrough
```

### Key Security Properties

- **TLS Everywhere:** All external traffic is encrypted via Let's Encrypt
  certificates managed by Traefik.
- **Container Isolation:** Services run in isolated Docker containers on an
  internal bridge network (172.30.0.0/24).
- **Secret Management:** Secrets are stored in environment files (`.env`) and
  Docker Compose configuration. These files MUST NOT be committed to version
  control.
- **SSH Hardening:** SSH runs on a non-standard port with key-based
  authentication only. Password authentication is disabled.
- **Minimal Attack Surface:** Only ports 80, 443, and 51820/udp are exposed.
  The STUN port 3478/udp is also exposed for NAT traversal.

### What IS Considered a Vulnerability

- Unauthorized access to NetBird management API
- Bypass of authentication/authorization in Dashboard
- Remote code execution in any component
- Information disclosure of sensitive data (keys, tokens, user data)
- Denial of service that crashes core services
- TLS misconfiguration allowing MITM attacks
- Privilege escalation within the Docker/container environment

### What is NOT Considered a Vulnerability

- Issues in outdated/vulnerable dependencies that are not exploitable in our
  specific configuration (report them anyway - we will assess)
- Brute force attacks (we recommend fail2ban or similar)
- Phishing or social engineering attacks
- Physical security of the Hetzner data center
- DDoS attacks (these are infrastructure-level concerns)

## Security Best Practices for Operators

1. **Keep components updated:** Run `make update` regularly (monthly at minimum).
2. **Use strong secrets:** All secrets should be randomly generated with at
   least 256 bits of entropy.
3. **Restrict SSH access:** Use SSH keys only. Consider IP whitelisting.
4. **Enable firewall:** Use `ufw` or `iptables` to restrict access to only
   necessary ports.
5. **Monitor logs:** Review logs regularly for suspicious activity.
6. **Back up securely:** Encrypt backups and store them off-site.
7. **Rotate secrets:** Rotate proxy tokens and auth secrets periodically.

## Security Updates

Security patches are applied by updating Docker images:

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d
```

Monitor the [NetBird releases page](https://github.com/netbirdio/netbird/releases)
and [Traefik releases](https://github.com/traefik/traefik/releases) for
security announcements.
