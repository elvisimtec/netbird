# Upgrade Procedures

How to safely upgrade NetBird components and dependencies.

## Pre-Upgrade Checklist

- [ ] Read release notes for the new version
- [ ] Create a backup (`make backup`)
- [ ] Check for breaking changes in docker-compose or config format
- [ ] Schedule a maintenance window (5-15 minutes)
- [ ] Notify users if downtime is expected

## Quick Upgrade (Standard)

```bash
make update-stack
```

This runs backup first, then pulls new images and restarts services.

## Manual Upgrade

### 1. Backup

```bash
make backup
```

### 2. Pull New Images

```bash
docker compose pull
```

### 3. Check for Configuration Changes

Compare your config files with the latest examples:

```bash
# Check docker-compose.yml changes (if tracking upstream)
git diff main

# Review NetBird release notes
# https://github.com/netbirdio/netbird/releases
```

### 4. Apply Updates

```bash
docker compose up -d --remove-orphans
```

The `--remove-orphans` flag removes containers for services that were removed
from the compose file.

### 5. Verify

```bash
make status
make health-check
make logs-server  # Check for errors
```

### 6. Clean Up

```bash
# Remove old (unused) Docker images
docker image prune -f
```

## Component-Specific Upgrades

### NetBird Server

```bash
# Pull and restart only the server
docker compose pull netbird-server
docker compose up -d netbird-server

# Check logs for migration messages
docker compose logs netbird-server --tail 50
```

The server automatically runs database migrations on startup.

### NetBird Dashboard

```bash
docker compose pull dashboard
docker compose up -d dashboard
```

### NetBird Proxy

```bash
docker compose pull proxy
docker compose up -d proxy
```

> **Note:** Proxy restart will temporarily disconnect WireGuard peers.
> They should reconnect automatically within 30-60 seconds.

### Traefik

```bash
# Check Traefik release notes and migration guide first!
# https://doc.traefik.io/traefik/migration/

docker compose pull traefik
docker compose up -d traefik
```

Traefik upgrades can have breaking changes between major versions. Always read
the migration guide.

### Docker Engine

```bash
# Update package lists
sudo apt update

# Upgrade Docker
sudo apt install --only-upgrade docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Restart Docker
sudo systemctl restart docker

# Restart services
cd /opt/netbird
docker compose up -d
```

## Rollback Procedure

If an upgrade causes issues:

### 1. Identify the Previous Working Version

```bash
# Check Docker image history
docker images | grep netbirdio

# Or check git history for the compose file's previous image tags
git log --oneline docker-compose.yml
```

### 2. Pin to Previous Version

Edit `docker-compose.yml` and pin the image to the previous working version:

```yaml
netbird-server:
  image: netbirdio/netbird-server:v0.74.6  # Specific version
```

### 3. Restart with Pinned Version

```bash
docker compose up -d netbird-server
```

### 4. Verify

```bash
make health-check
```

## Database Migrations

NetBird server runs automatic migrations on startup. These are generally safe
and backward-compatible within minor versions.

### Pre-Migration Backup

Always back up the SQLite database before a major version upgrade:

```bash
docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db .dump > pre-upgrade-backup.sql
```

### If Migration Fails

If the server fails to start after an upgrade due to migration issues:

1. Check logs: `docker compose logs netbird-server`
2. Restore from backup: See [Backup and Restore](backup-restore.md)
3. Pin to previous version and report the issue

## Dependency Updates (Dependabot)

GitHub Dependabot is configured to auto-update GitHub Actions only.
Infrastructure dependencies (Docker images) are managed manually through
`docker-compose.yml`.

To update pinned versions manually:

```bash
# Check available versions
docker pull netbirdio/netbird-server:latest
docker inspect netbirdio/netbird-server:latest | grep -A5 Labels

# Update in docker-compose.yml
# vim docker-compose.yml
# docker compose up -d
```

## Version Compatibility Matrix

| NetBird Server | NetBird Dashboard | NetBird Proxy | Traefik | Status |
|---------------|-------------------|---------------|---------|--------|
| v0.74.x | latest | latest | v3.6 | ✅ Current |
| v0.73.x | latest | latest | v3.x | ✅ Compatible |

Always check the [NetBird releases page](https://github.com/netbirdio/netbird/releases)
for version-specific upgrade notes.
