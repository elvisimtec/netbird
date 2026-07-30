# Incident Response

Procedures for responding to security incidents affecting the NetBird
infrastructure.

## Incident Classification

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| **P1 — Critical** | Active breach, data exfiltration, full service compromise | Immediate | Unauthorized root access, database stolen |
| **P2 — High** | Service vulnerability actively exploited, partial compromise | < 4 hours | Dashboard auth bypass, proxy token leaked |
| **P3 — Medium** | Vulnerability identified, not yet exploited | < 24 hours | Outdated vulnerable dependency, config weakness |
| **P4 — Low** | Minor security concern, informational | < 1 week | Non-optimal security header, log noise |

## Incident Response Process

### 1. Detection

Incidents may be detected through:
- Monitoring alerts (health checks, log scanning)
- User reports
- Security scan results (GitHub CodeQL, Gitleaks)
- External disclosure (see SECURITY.md)

### 2. Initial Triage

Upon detection, immediately assess:

- **What** system/component is affected?
- **When** did it start?
- **Who** is impacted?
- **How** severe is it (P1-P4)?

### 3. Containment

#### P1/P2 — Immediate Actions

**Server Compromise:**
```bash
# 1. Isolate the server (keep it running for forensics)
# From Hetzner Cloud Console: add firewall rule blocking all traffic
# EXCEPT your management IP

# 2. Take a snapshot for forensics
# Hetzner Cloud Console → Server → Snapshots → Take Snapshot

# 3. Revoke all secrets immediately
# - Rotate SSH keys
# - Rotate all tokens and auth secrets
# - Revoke Let's Encrypt certificates
```

**Data Breach:**
```bash
# 1. Identify what was accessed
docker compose logs --since 24h | grep -E "unauthorized|access denied|error"

# 2. Check database for unauthorized changes
docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db \
  "SELECT * FROM users ORDER BY created_at DESC LIMIT 10;"

# 3. Notify affected users if personal data was exposed
```

**Secret Leak:**
```bash
# If secrets were committed to git:
# 1. Rotate all exposed secrets immediately
# 2. Rewrite git history (if public repo)
# 3. Check if unauthorized access occurred using the exposed secrets
```

### 4. Investigation

Collect forensic evidence:

```bash
# System logs
sudo journalctl --since "24 hours ago" > /tmp/incident-journal.log

# Auth logs
sudo cp /var/log/auth.log /tmp/incident-auth.log

# Docker logs (all containers)
docker compose logs --since 24h > /tmp/incident-docker.log

# Bash history
cp ~/.bash_history /tmp/incident-bash-history

# Currently open connections
ss -tlnpu > /tmp/incident-connections.txt

# Running processes
ps auxf > /tmp/incident-processes.txt

# Recent file changes
sudo find /opt/netbird -mtime -1 -ls > /tmp/incident-files.txt
```

### 5. Remediation

#### Server Compromise Recovery

```bash
# DO NOT reuse a compromised server — rebuild from scratch

# 1. Provision new server
# 2. Run docker.sh for initial setup
# 3. Restore from LAST KNOWN GOOD backup
# 4. Deploy with ALL NEW secrets
# 5. Rotate ALL credentials (SSH keys, API tokens, proxy tokens)
# 6. Update DNS to point to new IP
```

#### Partial Service Compromise

```bash
# 1. Stop the affected service
docker compose stop <service>

# 2. Verify data integrity
docker compose exec netbird-server sqlite3 /var/lib/netbird/store.db "PRAGMA integrity_check;"

# 3. Restore affected service from backup if needed

# 4. Apply security patches / upgrade

# 5. Restart with verification
docker compose up -d <service>
make health-check
```

### 6. Recovery Verification

```bash
# Verify all services
make status
make health-check

# Verify no unauthorized access persists
docker compose logs --since 1h | grep -E "unauthorized|error"

# Verify TLS certificates are valid
echo | openssl s_client -servername netb.koorpa.ba -connect netb.koorpa.ba:443 2>/dev/null | openssl x509 -noout -dates
```

### 7. Post-Incident

- [ ] Document the full incident timeline
- [ ] Identify root cause
- [ ] Implement preventive measures
- [ ] Update security policies/procedures
- [ ] Conduct a post-mortem review
- [ ] Notify stakeholders (if applicable)
- [ ] Update CHANGELOG.md with security fix details

## Specific Incident Playbooks

### Playbook: Unauthorized SSH Access

```bash
# 1. Identify the session
who
w
last | head -20

# 2. Kill unauthorized sessions
sudo pkill -u <username>

# 3. Check for persistence
crontab -l
cat ~/.ssh/authorized_keys
sudo find / -name "authorized_keys" -exec cat {} \;

# 4. Revoke and rotate all SSH keys
# 5. Check for backdoors
sudo find / -user root -perm -4000 -ls  # SUID binaries
sudo find / -nouser -o -nogroup -ls       # Orphaned files
```

### Playbook: Ransomware or Data Destruction

```bash
# 1. IMMEDIATELY stop all Docker containers
docker compose down

# 2. Take volume snapshot before any changes
# Hetzner Cloud Console → Volumes → Snapshot

# 3. Check database integrity
docker run --rm -v netbird_data:/data alpine cat /data/store.db > /tmp/store-check.db
sqlite3 /tmp/store-check.db "PRAGMA integrity_check;"

# 4. Restore from backup
# See docs/operations/backup-restore.md
```

### Playbook: Let's Encrypt Certificate Revocation

If certificates are compromised:

```bash
# 1. Force Traefik to get new certificates
docker compose stop traefik
rm -rf /var/lib/docker/volumes/netbird_traefik_letsencrypt/_data/*
docker compose up -d traefik

# 2. Wait for new certificates (30-60 seconds)
docker compose logs traefik | grep -i acme

# 3. Verify new certs
echo | openssl s_client -servername netb.koorpa.ba -connect netb.koorpa.ba:443 2>/dev/null | openssl x509 -noout -dates -issuer
```

## Communication Templates

### Internal Incident Notification

```
Subject: [SECURITY INCIDENT] NetBird Infrastructure — P<N> <Title>

Severity: P<N>
Date/Time Detected: <timestamp>
Status: <Investigating|Contained|Resolved>

Impact:
- Affected component(s): <list>
- User impact: <description>
- Data exposure: <yes/no, details>

Actions Taken:
- <list of containment actions>

Next Steps:
- <planned remediation>

Contact: <point of contact>
```

### User Notification (if data breach)

```
Subject: Security Incident Affecting NetBird VPN Service

Dear NetBird users,

We are writing to inform you of a security incident affecting the
NetBird VPN service at netb.koorpa.ba.

What happened:
<clear, factual description>

What data was affected:
<specific data types>

What we are doing:
<remediation actions>

What you should do:
<user actions, if any>

We will provide an update by <date/time>.

Contact: <security contact>
```

## Recovery Time Objectives (RTO)

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single container failure | 5 minutes | 0 |
| Server reboot | 10 minutes | 0 |
| Full server rebuild | 2 hours | 24 hours (from backup) |
| Data corruption | 1 hour | Last backup |
| Security compromise | 3 hours | Last known good backup |

## Contacts

| Role | Contact |
|------|---------|
| Infrastructure Owner | [INSERT] |
| Security Contact | [INSERT] |
| Hetzner Support | https://www.hetzner.com/support |
| Upstream NetBird Security | https://github.com/netbirdio/netbird/security |
