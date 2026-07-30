# Troubleshooting

Common issues and their solutions for the NetBird infrastructure.

---

## Service Issues

### All containers down

```bash
# Check Docker is running
sudo systemctl status docker

# Start Docker if stopped
sudo systemctl start docker

# Restart services
docker compose up -d
make status
```

### One container is restarting

```bash
# Check logs for the failing container
docker compose logs --tail=50 <container-name>

# Common causes:
# - Port conflict: another process using the same port
# - Config error: check the relevant .env or .yaml file
# - Volume permission: check mounted volume permissions
```

### Container exits immediately

```bash
# Check exit code
docker compose ps -a

# Run with interactive logging
docker compose up <container-name>
```

---

## Traefik Issues

### No TLS certificate (self-signed warning)

**Symptoms:** Browser shows certificate warning, `NET::ERR_CERT_AUTHORITY_INVALID`

**Cause:** Let's Encrypt hasn't issued a certificate yet or renewal failed.

**Fix:**
```bash
# Check Traefik logs for ACME errors
docker compose logs traefik | grep -i acme

# Common ACME issues:
# 1. Domain not pointing to server: check DNS
# 2. Port 80 blocked: check firewall
# 3. Rate limited: wait 1 hour (5 certs/hour/domain limit)

# Force Traefik to retry
docker compose restart traefik
```

### 502 Bad Gateway

**Symptoms:** Browser shows 502 or "Bad Gateway"

**Cause:** Backend service not running or not reachable by Traefik.

**Fix:**
```bash
# Check the target service is running
docker compose ps

# Check network connectivity
docker compose exec traefik wget -qO- http://netbird-server:80/health 2>&1

# Check Traefik routing
docker compose logs traefik | grep -i "502\|bad gateway"
```

### gRPC connection failures

**Symptoms:** Agents cannot connect, "connection refused" or timeout errors.

**Fix:**
```bash
# Verify h2c service is configured
docker compose logs traefik | grep -i "h2c\|grpc"

# Check gRPC timeouts in docker-compose.yml
# Ensure these are set to 0:
# - respondingTimeouts.readTimeout
# - respondingTimeouts.writeTimeout
# - respondingTimeouts.idleTimeout
```

---

## NetBird Server Issues

### Server not starting

```bash
# Check logs for errors
docker compose logs netbird-server --tail 100

# Common startup errors:
# 1. Invalid config.yaml syntax: validate with yamllint
# 2. Port already in use: check other processes
# 3. Database corruption: restore from backup

# Validate config
docker compose run --rm netbird-server --config /etc/netbird/config.yaml --help
```

### Database errors

```bash
# Check database integrity
docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db "PRAGMA integrity_check;"

# If corrupted, restore from backup
# See docs/operations/backup-restore.md

# Check file permissions
docker compose exec netbird-server ls -la /var/lib/netbird/
```

### High CPU or memory usage

```bash
# Check resource usage
docker stats netbird-server --no-stream

# Check number of connected peers via logs
docker compose logs netbird-server | grep "peer connected" | wc -l

# Check for unusually high peer count
docker compose logs netbird-server --since 1h | grep -c "peer connected"
```

---

## Dashboard Issues

### Blank page or loading forever

```bash
# Check Dashboard env variables
docker compose exec dashboard env | grep -E "NETBIRD|AUTH"

# Verify Dashboard can reach server
docker compose exec dashboard wget -qO- http://netbird-server:80/api/health

# Check browser console for errors (F12 → Console)
# Common: CORS errors, OIDC misconfiguration
```

### OIDC login fails

**Symptoms:** "Invalid redirect URI" or OIDC flow doesn't complete.

**Fix:**
```bash
# Verify redirect URIs match between config.yaml and dashboard.env
# config.yaml:
#   dashboardRedirectURIs:
#     - "https://<domain>/nb-auth"
#     - "https://<domain>/nb-silent-auth"
# dashboard.env:
#   AUTH_REDIRECT_URI=/nb-auth
#   AUTH_SILENT_REDIRECT_URI=/nb-silent-auth

# Check the domain matches in ALL places
grep -r "netb.koorpa.ba" *.yml *.yaml *.env
```

---

## Proxy Issues

### Peers cannot connect via WireGuard

```bash
# Verify proxy is running
docker compose ps proxy

# Check proxy logs
docker compose logs proxy --tail 50

# Verify WireGuard port is accessible
# From an external machine:
nc -u -v <server-ip> 51820
```

### Proxy token invalid

**Symptoms:** Proxy logs show "unauthorized" or "invalid token".

**Fix:**
1. Generate a new token and update `proxy.env`
2. Restart the proxy: `docker compose restart proxy`
3. Re-register the proxy in the dashboard (Settings → Proxy)

---

## Network Issues

### DNS resolution problems

```bash
# Check DNS on server
nslookup netb.koorpa.ba
dig netb.koorpa.ba

# Check from inside containers
docker compose exec netbird-server nslookup netb.koorpa.ba
```

### STUN not working

```bash
# Verify STUN port published
docker compose ps | grep 3478

# Test STUN from external
# Using stunclient (apt install stuntman-client)
stunclient <server-ip> 3478
```

---

## Quick Reference

| Problem | First Command |
|---------|--------------|
| Any issue | `make status` |
| Container won't start | `docker compose logs <name> --tail=50` |
| Certificate issue | `docker compose logs traefik \| grep acme` |
| Dashboard blank | Browser DevTools (F12) → Console |
| Peer can't connect | `docker compose logs proxy --tail=50` |
| Server errors | `docker compose logs netbird-server \| grep -i error` |
| Database check | `docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db "PRAGMA integrity_check;"` |
| Full restart | `docker compose down && docker compose up -d` |
| Emergency | `make status; make logs --tail=100; make health-check` |
