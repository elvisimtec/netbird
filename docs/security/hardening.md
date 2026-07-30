# Security Hardening

Best practices for hardening the NetBird infrastructure deployment.

## SSH Hardening

### Current Configuration (as deployed)

- Non-standard port (2416)
- Key-based authentication only (password auth disabled)
- Root login with key

### Recommended Improvements

```bash
# /etc/ssh/sshd_config
Port 2416
PermitRootLogin prohibit-password
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2

# Restart SSH
sudo systemctl restart sshd
```

### SSH Key Management

```bash
# Use ed25519 keys (modern, secure)
ssh-keygen -t ed25519 -C "netbird-admin"

# Add a passphrase
ssh-keygen -p -f ~/.ssh/id_ed25519
```

### fail2ban (Brute Force Protection)

```bash
sudo apt install fail2ban -y

# Create /etc/fail2ban/jail.local
cat << 'EOF' | sudo tee /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 2416
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Firewall (UFW)

```bash
# Install if not present
sudo apt install ufw -y

# Default deny incoming
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow only required ports
sudo ufw allow 2416/tcp                 # SSH
sudo ufw allow 80/tcp                   # HTTP (redirect only)
sudo ufw allow 443/tcp                  # HTTPS
sudo ufw allow 3478/udp                 # STUN
sudo ufw allow 51820/udp                # WireGuard

# Enable
sudo ufw enable
sudo ufw status verbose
```

**Important:** If using Hetzner Cloud, also configure firewall rules in the
Hetzner Cloud Console as a second layer of defense.

## Docker Security

### Container Security

```bash
# Run containers as non-root user (where possible)
# Add to docker-compose.yml:
#   user: "1000:1000"

# Read-only root filesystem (for stateless services)
#   read_only: true

# Drop all capabilities, add only needed ones
#   cap_drop:
#     - ALL
#   cap_add:
#     - NET_BIND_SERVICE
```

### Docker Daemon Security

```bash
# /etc/docker/daemon.json
cat << 'EOF' | sudo tee /etc/docker/daemon.json
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "500m",
    "max-file": "2"
  },
  "userland-proxy": false,
  "no-new-privileges": true
}
EOF

sudo systemctl restart docker
```

- `icc: false` — Disables inter-container communication (containers can only
  communicate via explicitly created networks)
- `userland-proxy: false` — Uses iptables for port forwarding (faster, more secure)
- `no-new-privileges: true` — Prevents containers from gaining new privileges

### Docker Socket Protection

The Docker socket is mounted read-only (`:ro`) in the Traefik container.
Never mount it as read-write unless absolutely necessary.

## Secrets Management

### Current Approach

Secrets are stored in `.env` files on the server. These files are:
- Git-ignored (never committed)
- Restricted file permissions (`chmod 600`)
- Owner-restricted (`chown netb4521:netb4521`)

### File Permissions

```bash
# Ensure proper permissions on all config files
cd /opt/netbird
chmod 600 .env proxy.env dashboard.env config.yaml
chmod 644 docker-compose.yml traefik-dynamic.yaml
chown -R netb4521:netb4521 .
```

### Secret Rotation

Regularly rotate these secrets:

| Secret | Location | Rotation Impact |
|--------|----------|-----------------|
| `authSecret` | `config.yaml` | Invalidates all auth tokens — users must re-login |
| `encryptionKey` | `config.yaml` | **Cannot rotate** after data exists — requires migration |
| `NB_PROXY_TOKEN` | `proxy.env` | Disconnects all WireGuard peers — reconnect needed |

**Rotation procedure:**
```bash
# Example: rotate proxy token
# 1. Generate new token
NEW_TOKEN=$(openssl rand -base64 32)

# 2. Update proxy.env
sed -i "s/NB_PROXY_TOKEN=.*/NB_PROXY_TOKEN=$NEW_TOKEN/" proxy.env

# 3. Restart proxy
docker compose restart proxy

# 4. Update the token in Dashboard (Settings → Proxy)
```

## TLS Configuration

### Minimum TLS Version (Traefik)

Add to Traefik command in `docker-compose.yml`:

```yaml
- "--entrypoints.websecure.http.tls.options=default@file"
```

Create TLS options in `traefik-dynamic.yaml`:

```yaml
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
```

### HTTP Security Headers

Add middleware in `traefik-dynamic.yaml`:

```yaml
http:
  middlewares:
    security-headers:
      headers:
        frameDeny: true
        sslRedirect: true
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
```

Then apply to routers via labels in `docker-compose.yml`:

```yaml
- "traefik.http.routers.netbird-backend.middlewares=security-headers@file"
```

## System Hardening

### Automatic Security Updates

```bash
sudo apt install unattended-upgrades -y

# Configure
sudo dpkg-reconfigure -plow unattended-upgrades

# Enable automatic updates for security patches
# /etc/apt/apt.conf.d/50unattended-upgrades
# Unattended-Upgrade::Allowed-Origins {
#     "${distro_id}:${distro_codename}-security";
# };
```

### Kernel Hardening

```bash
# /etc/sysctl.d/99-security.conf
cat << 'EOF' | sudo tee /etc/sysctl.d/99-security.conf
# IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
EOF

sudo sysctl -p /etc/sysctl.d/99-security.conf
```

### Audit System

```bash
# Install auditd
sudo apt install auditd -y

# Configure audit rules for key files
sudo auditctl -w /opt/netbird/config.yaml -p wa -k netbird-config
sudo auditctl -w /opt/netbird/proxy.env -p wa -k netbird-secrets
sudo auditctl -w /etc/ssh/sshd_config -p wa -k ssh-config

# Make persistent
# Add rules to /etc/audit/rules.d/netbird.rules

sudo systemctl enable auditd
```

## Regular Security Tasks

### Daily
- [ ] Review auth logs: `sudo tail -50 /var/log/auth.log`

### Weekly
- [ ] Check for unusual login attempts: `sudo lastb | head -20`
- [ ] Review Docker container logs for suspicious activity
- [ ] Verify firewall rules: `sudo ufw status verbose`

### Monthly
- [ ] Apply system updates: `sudo apt update && sudo apt upgrade -y`
- [ ] Check for Docker image updates: `docker compose pull --dry-run`
- [ ] Rotate secrets (if scheduled)
- [ ] Review fail2ban status: `sudo fail2ban-client status sshd`

### Quarterly
- [ ] Full security audit
- [ ] Penetration testing (internal)
- [ ] Review and update security policies
- [ ] Test backup restore from scratch
