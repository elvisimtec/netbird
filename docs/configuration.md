# Configuration Reference

Complete reference of all configuration options for the NetBird infrastructure.

## Files Overview

| File | Purpose | Sensitive |
|------|---------|-----------|
| `docker-compose.yml` | Service orchestration | No |
| `config.yaml` | NetBird server runtime config | Yes (secrets) |
| `dashboard.env` | Dashboard environment variables | No |
| `proxy.env` | Proxy configuration | Yes (token) |
| `traefik-dynamic.yaml` | Traefik TCP-level settings | No |
| `.env` | SSH connection details | Yes (passwords) |

---

## docker-compose.yml

### Traefik Service

```yaml
traefik:
  image: traefik:v3.6           # Pinned version for stability
  restart: unless-stopped
  networks:
    netbird:
      ipv4_address: 172.30.0.10 # Static IP required for proxy trust
```

| Setting | Default | Description |
|---------|---------|-------------|
| `image` | `traefik:v3.6` | Traefik version. Pin to specific version. |
| `ipv4_address` | `172.30.0.10` | Must match trusted proxy IPs in other configs. |

**Labels:**

Traefik routes are defined via Docker labels on the target services, not on
the Traefik container itself.

**Volumes:**

| Mount | Purpose |
|-------|---------|
| `/var/run/docker.sock:ro` | Docker provider (read-only) |
| `netbird_traefik_letsencrypt:/letsencrypt` | Let's Encrypt certificates |
| `./traefik-dynamic.yaml:/etc/traefik/dynamic.yaml:ro` | Dynamic config |

**Command-line arguments:**

| Argument | Value | Description |
|----------|-------|-------------|
| `--log.level` | `INFO` | Log level: DEBUG, INFO, WARN, ERROR |
| `--accesslog` | `true` | Enable access logging |
| `--providers.docker` | `true` | Enable Docker provider |
| `--providers.docker.exposedbydefault` | `false` | Only expose labeled containers |
| `--providers.docker.network` | `netbird` | Docker network to watch |
| `--entrypoints.web.address` | `:80` | HTTP entrypoint |
| `--entrypoints.websecure.address` | `:443` | HTTPS entrypoint |
| `--certificatesresolvers.letsencrypt.acme.email` | `admin@koorpa.ba` | Let's Encrypt contact email |
| `--certificatesresolvers.letsencrypt.acme.storage` | `/letsencrypt/acme.json` | Certificate storage |
| `--certificatesresolvers.letsencrypt.acme.tlschallenge` | `true` | Use TLS challenge |

**gRPC timeout settings:**

Extended timeouts are required for long-lived gRPC streams:

```yaml
- "--entrypoints.websecure.transport.respondingTimeouts.readTimeout=0"
- "--entrypoints.websecure.transport.respondingTimeouts.writeTimeout=0"
- "--entrypoints.websecure.transport.respondingTimeouts.idleTimeout=0"
- "--serverstransport.forwardingtimeouts.responseheadertimeout=0s"
- "--serverstransport.forwardingtimeouts.idleconntimeout=0s"
```

Setting timeouts to `0` disables them — necessary for persistent agent connections.

### Dashboard Service

```yaml
dashboard:
  image: netbirdio/dashboard:latest
  env_file: ./dashboard.env
```

| Setting | Description |
|---------|-------------|
| `image` | Dashboard version. `latest` pulls newest on restart. |

### NetBird Server Service

```yaml
netbird-server:
  image: netbirdio/netbird-server:latest
  ports:
    - '3478:3478/udp'
  volumes:
    - netbird_data:/var/lib/netbird
    - ./config.yaml:/etc/netbird/config.yaml
  command: ["--config", "/etc/netbird/config.yaml"]
```

| Setting | Description |
|---------|-------------|
| `3478:3478/udp` | STUN port for NAT traversal |
| `netbird_data:/var/lib/netbird` | Persistent data (SQLite, config) |
| `--config` | Path to NetBird server config |

### Proxy Service

```yaml
proxy:
  image: netbirdio/reverse-proxy:latest
  ports:
    - 51820:51820/udp
  env_file: ./proxy.env
  volumes:
    - netbird_proxy_certs:/certs
```

| Setting | Description |
|---------|-------------|
| `51820:51820/udp` | WireGuard tunnel port |
| `netbird_proxy_certs:/certs` | Proxy TLS certificates |

---

## config.yaml

### Server Settings

```yaml
server:
  listenAddress: ":80"
  exposedAddress: "https://netb.koorpa.ba:443"
  stunPorts:
    - 3478
  metricsPort: 9090
  healthcheckAddress: ":9000"
  logLevel: "info"
  logFile: "console"
```

| Setting | Description |
|---------|-------------|
| `listenAddress` | Internal listen address. Must be `:80` for h2c. |
| `exposedAddress` | Public URL clients connect to. |
| `stunPorts` | STUN port list. Must match published port. |
| `metricsPort` | Prometheus metrics endpoint (internal). |
| `healthcheckAddress` | Health check endpoint. |
| `logLevel` | Log level: trace, debug, info, warn, error. |
| `logFile` | `console` for stdout, or file path. |

### Auth Settings

```yaml
server:
  authSecret: "<base64-secret>"
  auth:
    issuer: "https://netb.koorpa.ba/oauth2"
    signKeyRefreshEnabled: true
    dashboardRedirectURIs:
      - "https://netb.koorpa.ba/nb-auth"
      - "https://netb.koorpa.ba/nb-silent-auth"
    cliRedirectURIs:
      - "http://localhost:53000/"
```

| Setting | Description |
|---------|-------------|
| `authSecret` | Secret for signing auth tokens. Generate with `openssl rand -base64 32`. |
| `issuer` | OIDC issuer URL. Must match `AUTH_AUTHORITY` in dashboard.env. |
| `signKeyRefreshEnabled` | Auto-rotate signing keys. |
| `dashboardRedirectURIs` | Allowed redirect URIs for dashboard OIDC flow. |
| `cliRedirectURIs` | Allowed redirect URIs for CLI login. |

### Store Settings

```yaml
server:
  store:
    engine: "sqlite"
    encryptionKey: "<base64-key>"
```

| Setting | Description |
|---------|-------------|
| `engine` | `sqlite` (single server) or `postgres` (multi-server). |
| `encryptionKey` | 256-bit encryption key. Generate with `openssl rand -base64 32`. |

### Proxy Trust

```yaml
server:
  reverseProxy:
    trustedHTTPProxies:
      - "172.30.0.10/32"
```

Must match Traefik's static IP on the internal Docker network.

---

## dashboard.env

| Variable | Default | Description |
|----------|---------|-------------|
| `NETBIRD_MGMT_API_ENDPOINT` | `https://netb.koorpa.ba` | Management API URL |
| `NETBIRD_MGMT_GRPC_API_ENDPOINT` | `https://netb.koorpa.ba` | gRPC API URL |
| `AUTH_AUDIENCE` | `netbird-dashboard` | OIDC audience |
| `AUTH_CLIENT_ID` | `netbird-dashboard` | OIDC client ID |
| `AUTH_CLIENT_SECRET` | (empty) | OIDC client secret (empty for PKCE) |
| `AUTH_AUTHORITY` | `https://netb.koorpa.ba/oauth2` | OIDC provider URL |
| `USE_AUTH0` | `false` | Use Auth0 instead of embedded IdP |
| `AUTH_SUPPORTED_SCOPES` | `openid profile email groups` | OIDC scopes |
| `AUTH_REDIRECT_URI` | `/nb-auth` | Auth callback path |
| `AUTH_SILENT_REDIRECT_URI` | `/nb-silent-auth` | Silent auth callback |
| `NGINX_SSL_PORT` | `443` | SSL port for Nginx in Dashboard |
| `LETSENCRYPT_DOMAIN` | `none` | Set to domain for Dashboard-managed TLS (we use Traefik instead) |

---

## proxy.env

| Variable | Default | Description |
|----------|---------|-------------|
| `NB_PROXY_DEBUG_LOGS` | `false` | Enable debug logging |
| `NB_PROXY_MANAGEMENT_ADDRESS` | `http://netbird-server:80` | Internal management URL |
| `NB_PROXY_ALLOW_INSECURE` | `true` | Allow non-TLS to internal management |
| `NB_PROXY_DOMAIN` | `netb.koorpa.ba` | Public domain |
| `NB_PROXY_ADDRESS` | `:8443` | Proxy listen address |
| `NB_PROXY_TOKEN` | (required) | Proxy registration token |
| `NB_PROXY_CERTIFICATE_DIRECTORY` | `/certs` | TLS certificate storage |
| `NB_PROXY_ACME_CERTIFICATES` | `true` | Use ACME for proxy TLS |
| `NB_PROXY_ACME_CHALLENGE_TYPE` | `tls-alpn-01` | ACME challenge type |
| `NB_PROXY_FORWARDED_PROTO` | `https` | Forwarded protocol header |
| `NB_PROXY_PROXY_PROTOCOL` | `true` | Enable PROXY protocol |
| `NB_PROXY_TRUSTED_PROXIES` | `172.30.0.10` | Trusted proxy IPs |

---

## traefik-dynamic.yaml

```yaml
tcp:
  serversTransports:
    pp-v2:
      proxyProtocol:
        version: 2
```

Configures PROXY protocol v2 for the TCP passthrough transport. This enables
the proxy to see real client IPs through Traefik's TCP passthrough.

---

## Network Configuration

```yaml
networks:
  netbird:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/24
          gateway: 172.30.0.1
```

| Setting | Value | Description |
|---------|-------|-------------|
| `driver` | `bridge` | Standard Docker bridge network |
| `subnet` | `172.30.0.0/24` | Internal network range |
| `gateway` | `172.30.0.1` | Docker host on internal network |

## Volumes

```yaml
volumes:
  netbird_data:                  # Server SQLite data
  netbird_traefik_letsencrypt:   # Let's Encrypt certificates
  netbird_proxy_certs:           # Proxy TLS certificates
```

Volumes persist across container restarts and recreations. They are NOT
deleted by `docker compose down` (only by `docker compose down -v`).
