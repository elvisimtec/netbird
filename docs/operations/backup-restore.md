# Backup and Restore

Procedures for backing up and restoring the NetBird infrastructure.

## What to Back Up

| Item | Location | Importance |
|------|----------|------------|
| SQLite database | Docker volume `netbird_data` | **Critical** — all NetBird data |
| Let's Encrypt certs | Docker volume `netbird_traefik_letsencrypt` | Medium — can be reissued |
| Proxy certs | Docker volume `netbird_proxy_certs` | Medium — can be reissued |
| Configuration files | `*.yml`, `*.yaml`, `*.env` | **Critical** — deployment config |
| Docker images | Docker image cache | Low — can be re-pulled |

## Automated Backup

Use the Makefile target for a quick config backup:

```bash
make backup
```

This copies all configuration files to a timestamped directory. For a complete
backup including the SQLite database, use the manual procedure below.

## Manual Full Backup

### 1. Backup Configuration Files

```bash
BACKUP_DIR="netbird-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Copy all config files
cp docker-compose.yml config.yaml dashboard.env proxy.env traefik-dynamic.yaml "$BACKUP_DIR/"
cp docker.sh "$BACKUP_DIR/" 2>/dev/null
```

### 2. Backup SQLite Database

**Method A: Dump to SQL (recommended)**

```bash
# Dump the SQLite database to a SQL file
docker compose exec -T netbird-server sqlite3 /var/lib/netbird/store.db .dump > "$BACKUP_DIR/store.sql"
```

**Method B: Copy the database file**

```bash
# Copy the raw database file from the volume
docker compose cp netbird-server:/var/lib/netbird/store.db "$BACKUP_DIR/store.db"
```

**Important:** For the file copy method, ensure no writes are happening during
the copy. Dump to SQL is safer for live databases.

### 3. Backup Docker Volumes

```bash
# Backup volumes using a temporary container
docker run --rm \
  -v netbird_data:/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine tar czf /backup/netbird_data.tar.gz -C /data .

docker run --rm \
  -v netbird_traefik_letsencrypt:/data \
  -v "$(pwd)/$BACKUP_DIR":/backup \
  alpine tar czf /backup/traefik_letsencrypt.tar.gz -C /data .
```

### 4. Verify Backup

```bash
# Check backup contents
ls -la "$BACKUP_DIR/"
# Verify SQL dump is valid
head "$BACKUP_DIR/store.sql"
```

### 5. Store Backup Securely

```bash
# Compress and encrypt
tar czf - "$BACKUP_DIR" | gpg --symmetric --cipher-algo AES256 -o "$BACKUP_DIR.tar.gz.gpg"

# Copy off-server
scp "$BACKUP_DIR.tar.gz.gpg" user@backup-server:/backups/
```

## Automated Backup Script

Create `/opt/netbird/backup.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd /opt/netbird
BACKUP_DIR="netbird-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up to $BACKUP_DIR ..."

# Config files
cp docker-compose.yml config.yaml dashboard.env proxy.env traefik-dynamic.yaml "$BACKUP_DIR/"

# SQLite dump
docker compose exec -T netbird-server sqlite3 /var/lib/netbird/store.db .dump > "$BACKUP_DIR/store.sql"

# Compress
tar czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup complete: $BACKUP_DIR.tar.gz"
```

Add a cron job for daily backups:

```bash
# Run daily at 02:00
echo "0 2 * * * /opt/netbird/backup.sh" | crontab -

# Keep only last 7 backups
echo "0 3 * * * find /opt/netbird -name 'netbird-backup-*.tar.gz' -mtime +7 -delete" | crontab -
```

## Restore Procedure

### 1. Deploy Fresh Infrastructure

```bash
# Clone repository and configure
git clone https://github.com/elvisimtec/netbird.git /opt/netbird
cd /opt/netbird

# Copy your backed-up config files
cp /path/to/backup/docker-compose.yml .
cp /path/to/backup/config.yaml .
cp /path/to/backup/dashboard.env .
cp /path/to/backup/proxy.env .
cp /path/to/backup/traefik-dynamic.yaml .

# Start services (will create fresh volumes)
docker compose up -d
```

### 2. Stop Services

```bash
docker compose down
```

### 3. Restore SQLite Database

```bash
# If you have a SQL dump:
docker compose up -d netbird-server
docker compose exec -T netbird-server sqlite3 /var/lib/netbird/store.db < /path/to/backup/store.sql
docker compose restart netbird-server

# If you have the raw database file:
docker compose cp /path/to/backup/store.db netbird-server:/var/lib/netbird/store.db
docker compose restart netbird-server
```

### 4. Restart All Services

```bash
docker compose up -d
make health-check
```

### 5. Verify

- Dashboard accessible at `https://<domain>`
- Existing users and peers are present
- Agents can reconnect

## Disaster Recovery

If the entire server is lost:

1. **Provision a new server** (Hetzner VPS, Ubuntu 24.04 LTS)
2. **Run `docker.sh`** for initial setup
3. **Clone repository** and configure
4. **Restore from backup** following the procedure above
5. **Update DNS** if IP changed — update A record for your domain
6. **Verify Let's Encrypt** certificates are issued
7. **Notify users** of any downtime or IP changes
