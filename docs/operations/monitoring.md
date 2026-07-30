# Monitoring

How to monitor the NetBird infrastructure health and performance.

## Quick Health Check

```bash
make health-check
```

Output:
```
=== Container Status ===
NAME                STATUS
netbird-traefik     Up 2 weeks
netbird-dashboard   Up 2 weeks
netbird-server      Up 2 weeks
netbird-proxy       Up 2 weeks

=== NetBird Server Health ===
OK

=== Dashboard Reachable ===
HTTP 200
```

## Service Status

### Container Status

```bash
# Using Makefile
make status

# Direct
docker compose ps --format 'table {{.Name}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

Look for:
- All containers should be `Up`
- Health status should not show `unhealthy`
- Restart count should be low (or zero)

### Detailed Container Inspection

```bash
# Resource usage
docker stats --no-stream

# Container details
docker inspect netbird-server | jq '.[0].State'
```

## Logs

### Using Makefile

```bash
make logs           # All services
make logs-server    # Server only
make logs-dashboard # Dashboard only
make logs-proxy     # Proxy only
make logs-traefik   # Traefik only
```

### Direct Docker Commands

```bash
# Tail all logs
docker compose logs -f --tail=100

# Specific service, last 100 lines
docker compose logs --tail=100 netbird-server

# Logs since a specific time
docker compose logs --since 1h netbird-server

# Filter for errors
docker compose logs netbird-server 2>&1 | grep -i "error\|warn\|fatal"
```

### Log Rotation

All containers use `json-file` driver with:
- Max file size: 500 MB
- Max files: 2 per service

Total maximum log storage: ~4 GB (500MB × 2 files × 4 services).

To check log disk usage:
```bash
docker system df
```

## Endpoints

| Endpoint | URL | Description |
|----------|-----|-------------|
| Health Check | `http://localhost:9000/health` | NetBird server health |
| Metrics | `http://localhost:9090/metrics` | Prometheus metrics (internal) |
| Dashboard | `https://netb.koorpa.ba` | Web UI |
| API | `https://netb.koorpa.ba/api` | Management REST API |

### Health Check

```bash
# Server health
curl -s http://localhost:9000/health

# Expected: 200 OK with "ok" or similar
```

### Metrics (Prometheus)

The server exposes Prometheus metrics at port 9090 (internal only):

```bash
# View all metrics
curl -s http://localhost:9090/metrics | head -50

# Key metrics:
# netbird_management_peers_count
# netbird_management_users_count
# netbird_management_rules_count
```

To scrape metrics with Prometheus, add a Prometheus service to `docker-compose.yml`
and connect it to the `netbird` network.

## Alerting

### Critical Alerts (Set Up Externally)

| Condition | Check | Threshold |
|-----------|-------|-----------|
| Server down | `curl -sf http://localhost:9000/health` | Fails |
| Dashboard unreachable | `curl -sf -o /dev/null -w "%{http_code}" https://netb.koorpa.ba` | Not 200 |
| High log error rate | `docker compose logs --since 5m 2>&1 \| grep -c ERROR` | >10 |
| Disk space low | `df -h / \| awk 'NR==2 {print $5}'` | >80% |
| Container restarting | `docker compose ps \| grep -c Restarting` | >0 |
| SSL certificate expiry | `echo \| openssl s_client -servername netb.koorpa.ba -connect netb.koorpa.ba:443 2>/dev/null \| openssl x509 -noout -dates` | <7 days |

### Simple Alert Script

```bash
#!/bin/bash
# /opt/netbird/monitor.sh — basic health check with alerts

HOST="https://netb.koorpa.ba"

# Check health
if ! curl -sf http://localhost:9000/health > /dev/null; then
    echo "[ALERT] NetBird server health check failed at $(date)"
fi

# Check dashboard
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "$HOST")
if [ "$HTTP_CODE" != "200" ]; then
    echo "[ALERT] Dashboard returned HTTP $HTTP_CODE at $(date)"
fi

# Check containers
RESTARTING=$(docker compose ps | grep -c Restarting || true)
if [ "$RESTARTING" -gt 0 ]; then
    echo "[ALERT] $RESTARTING container(s) restarting at $(date)"
fi
```

## Resource Monitoring

### Disk Usage

```bash
# Filesystem
df -h

# Docker volumes
docker system df -v

# Log sizes
du -sh /var/lib/docker/containers/*/
```

### Memory and CPU

```bash
# Per-container
docker stats --no-stream

# System-wide
free -h
top -bn1 | head -5
```

### Network

```bash
# Open ports
ss -tlnpu

# Active connections to WireGuard
ss -an | grep 51820

# Traffic (requires iftop)
iftop -i eth0
```

## Performance Considerations

### SQLite Performance

SQLite performs well for small to medium deployments. Monitor:

```bash
# Database size
docker compose exec netbird-server ls -lh /var/lib/netbird/store.db

# Check for locks
docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db "PRAGMA integrity_check;"
```

If the database grows large (>100MB), consider:
- Regular VACUUM: `sqlite3 store.db "VACUUM;"`
- Migrating to PostgreSQL for larger deployments

### Traefik Performance

Monitor Traefik's built-in dashboard (if enabled) or check:
- Access log patterns for unusual traffic
- Memory usage during high connection counts
- TLS certificate renewal logs

## Regular Maintenance Checks

### Daily

- [ ] All containers running (`make status`)
- [ ] Health endpoint responds

### Weekly

- [ ] Review logs for errors
- [ ] Check disk space
- [ ] Verify backup is running

### Monthly

- [ ] Check for updates (`make update` with dry-run)
- [ ] Review security announcements
- [ ] Test backup restore procedure
- [ ] Rotate secrets (optional)
