# Deployment Guide

This guide covers deploying the NetBird infrastructure from scratch.

## Prerequisites

### Server Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB | 40 GB+ |
| Network | Public IP | Public IP + domain |

### External Requirements

1. **Domain name** pointing to server IP (`netb.imtec.ba` → server IP)
2. **SSH access** with key-based authentication
3. **Firewall rules** allowing ports: 80, 443, 3478/udp, 51820/udp

## Step 1: Initial Server Setup

Run the `docker.sh` script as root on a fresh Ubuntu server:

```bash
# Copy the script to the server
scp docker.sh root@<server-ip>:/root/

# SSH into the server and run
ssh root@<server-ip>
sudo bash /root/docker.sh
```

The script will:
1. Create a user account with sudo and Docker group membership
2. Install Docker Engine and Docker Compose
3. Configure SSH (port customization available)

## Step 2: Clone Repository

```bash
# As the created user (not root)
ssh <user>@<server-ip>
cd /opt
sudo mkdir netbird
sudo chown $USER:$USER netbird
git clone https://github.com/elvisimtec/netbird.git /opt/netbird
cd /opt/netbird
```

## Step 3: Configure Environment

### dashboard.env

```env
NETBIRD_MGMT_API_ENDPOINT=https://<your-domain>
NETBIRD_MGMT_GRPC_API_ENDPOINT=https://<your-domain>
AUTH_AUDIENCE=netbird-dashboard
AUTH_CLIENT_ID=netbird-dashboard
AUTH_CLIENT_SECRET=
AUTH_AUTHORITY=https://<your-domain>/oauth2
USE_AUTH0=false
AUTH_SUPPORTED_SCOPES=openid profile email groups
AUTH_REDIRECT_URI=/nb-auth
AUTH_SILENT_REDIRECT_URI=/nb-silent-auth
NGINX_SSL_PORT=443
LETSENCRYPT_DOMAIN=none
```

### proxy.env

```env
NB_PROXY_DEBUG_LOGS=false
NB_PROXY_MANAGEMENT_ADDRESS=http://netbird-server:80
NB_PROXY_ALLOW_INSECURE=true
NB_PROXY_DOMAIN=<your-domain>
NB_PROXY_ADDRESS=:8443
NB_PROXY_TOKEN=<generate-random-token>
NB_PROXY_CERTIFICATE_DIRECTORY=/certs
NB_PROXY_ACME_CERTIFICATES=true
NB_PROXY_ACME_CHALLENGE_TYPE=tls-alpn-01
NB_PROXY_FORWARDED_PROTO=https
NB_PROXY_PROXY_PROTOCOL=true
NB_PROXY_TRUSTED_PROXIES=172.30.0.10
```

Generate a secure proxy token:
```bash
openssl rand -base64 32
```

### config.yaml

```yaml
server:
  listenAddress: ":80"
  exposedAddress: "https://<your-domain>:443"
  stunPorts:
    - 3478
  metricsPort: 9090
  healthcheckAddress: ":9000"
  logLevel: "info"
  logFile: "console"

  authSecret: "<generate-random-secret>"
  dataDir: "/var/lib/netbird"

  auth:
    issuer: "https://<your-domain>/oauth2"
    signKeyRefreshEnabled: true
    dashboardRedirectURIs:
      - "https://<your-domain>/nb-auth"
      - "https://<your-domain>/nb-silent-auth"
    cliRedirectURIs:
      - "http://localhost:53000/"

  reverseProxy:
    trustedHTTPProxies:
      - "172.30.0.10/32"

  store:
    engine: "sqlite"
    encryptionKey: "<generate-encryption-key>"
```

Generate secrets:
```bash
# Auth secret
openssl rand -base64 32

# Encryption key
openssl rand -base64 32
```

### docker-compose.yml

Update the domain in the Traefik configuration:
```yaml
- "--certificatesresolvers.letsencrypt.acme.email=admin@<your-domain>"
```

And in all Traefik labels, replace `netb.imtec.ba` with your domain.

## Step 4: Deploy

```bash
# Deploy all services
make deploy

# Or manually
docker compose up -d
```

Wait 30-60 seconds for Let's Encrypt certificates to be issued.

## Step 5: Verify

```bash
# Check service status
make status

# Check health
make health-check

# Check logs
make logs
```

Expected result:
```
NAME                IMAGE                             STATUS          PORTS
netbird-traefik     traefik:v3.6                      Up X minutes    0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
netbird-dashboard   netbirdio/dashboard:latest        Up X minutes    80/tcp, 443/tcp
netbird-server      netbirdio/netbird-server:latest   Up X minutes    0.0.0.0:3478->3478/udp
netbird-proxy       netbirdio/reverse-proxy:latest    Up X minutes    0.0.0.0:51820->51820/udp
```

## Step 6: First Access

1. Open `https://<your-domain>` in a browser
2. Create an admin account
3. Follow the NetBird setup wizard

## Step 7: Client Setup

Install NetBird client on your devices:
```bash
# Linux
curl -fsSL https://pkgs.netbird.io/install.sh | sh

# macOS
brew install netbirdio/netbird/netbird

# Windows
winget install NetBird.NetBird
```

Connect:
```bash
netbird up --management-url https://<your-domain>:443
```

## Firewall Configuration

### UFW (Ubuntu)

```bash
sudo ufw allow 22/tcp     # SSH (or your custom port)
sudo ufw allow 80/tcp     # HTTP (redirect to HTTPS)
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 3478/udp   # STUN
sudo ufw allow 51820/udp  # WireGuard
sudo ufw enable
```

### Hetzner Firewall (Cloud Console)

If using Hetzner Cloud, configure firewall rules in the Cloud Console:
- Allow inbound TCP on ports 80, 443, and your SSH port
- Allow inbound UDP on ports 3478 and 51820

## Troubleshooting Deployment

### Certificates not issued

```bash
# Check Traefik logs
docker compose logs traefik | grep -i acme

# Common issues:
# - Domain not pointing to server IP
# - Port 80 not accessible (required for HTTP challenge)
# - Rate limiting (wait 1 hour)
```

### Dashboard shows blank page

```bash
# Check Dashboard can reach the server
docker compose exec dashboard curl -s http://netbird-server:80/api/health

# Check Dashboard env variables
docker compose exec dashboard env | grep NETBIRD
```

### Proxy not connecting

```bash
# Check proxy logs
docker compose logs proxy

# Verify proxy token matches config
docker compose exec proxy env | grep NB_PROXY_TOKEN

# Verify management is reachable from proxy
docker compose exec proxy curl -s http://netbird-server:80
```
