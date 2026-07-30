# Komodo Stack Management

Ovaj vodič pokriva upravljanje NetBird stackom kroz [Komodo](https://komo.do)
— open-source alat za upravljanje Docker stackovima.

## Pregled

NetBird stack je registrovan u Komodo-u sa sljedećom konfiguracijom:

| Resurs | Vrijednost |
|--------|-----------|
| **Core URL** | `https://komo-sso.imtec.ba` |
| **Server** | `NetBird` |
| **Stack Name** | `netbird` |
| **Project Name** | `netbird` |
| **Repo** | `imtec/netbird` (git.imtec.ba) |
| **Branch** | `main` |
| **Run Directory** | `/opt/stacks/netbird` |
| **Deploy Mode** | Ručni (manual) |
| **Auto Update** | Isključen |

## Arhitektura

```
/opt/stacks/netbird/
├── docker-compose.yml        ← Iz Git repo-a (Komodo upravlja)
├── traefik-dynamic.yaml      ← Iz Git repo-a
├── config.yaml               ← NA SERVERU SAMO (gitignored, secrets)
├── dashboard.env             ← NA SERVERU SAMO (gitignored, secrets)
├── proxy.env                 ← NA SERVERU SAMO (gitignored, secrets)
├── data/                     ← Docker volumes (gitignored)
│   ├── netbird/              ← SQLite baze (store.db, idp.db)
│   ├── letsencrypt/          ← TLS certifikati
│   └── proxy-certs/          ← Proxy TLS certifikati
└── scripts/                  ← Iz Git repo-a
```

**Važno:** Secret fajlovi (`config.yaml`, `*.env`) i `data/` direktorij su
gitignored. Komodo Git operacije (pull, refresh, redeploy) ih **ne diraju**.
Ovo je potvrđeno kao acceptance criterion prije migracije.

## Svakodnevne Operacije

### Deploy Stacka

```bash
# Kroz Komodo UI:
# Resources → netbird → Deploy
```

Ili sa servera (ako Komodo nije dostupan):
```bash
cd /opt/stacks/netbird
docker compose -p netbird up -d
```

### Stop Stacka

```bash
# Kroz Komodo UI:
# Resources → netbird → Stop
```

Ili sa servera:
```bash
cd /opt/stacks/netbird
docker compose -p netbird stop
```

### Restart Stacka

```bash
# Kroz Komodo UI:
# Resources → netbird → Restart
```

### Git Pull + Redeploy

Kad se ažurira `docker-compose.yml` ili `traefik-dynamic.yaml` u repo-u:

1. Komodo UI → Resources → netbird-repo → Pull
2. Komodo UI → Resources → netbird → Deploy

Ili sa servera:
```bash
cd /opt/stacks/netbird
git pull
docker compose -p netbird up -d
```

### Provjera Statusa

```bash
# Kroz Komodo UI: Resources → netbird → vidjet ćeš status svih kontejnera

# Sa servera:
docker compose -p netbird ps
docker ps --filter "label=com.docker.compose.project=netbird"
```

### Logovi

```bash
# Komodo UI: Resources → netbird → Logs (po kontejneru)

# Sa servera:
docker compose -p netbird logs -f --tail=100
docker compose -p netbird logs -f netbird-server
```

## Monitoring

Komodo prikazuje:
- **Status** svakog kontejnera (running/stopped/unhealthy)
- **CPU/Memory** korištenje po kontejneru
- **Logs** — live tail kroz UI
- **Alerts** — na stack state changes (uključeno preko `send_alerts = true`)

## Update Workflow

### Ažuriranje Docker Image-a

1. Provjeri da li postoje novi image-i:
   - Komodo UI → Resources → netbird → prikazat će indikator ako ima novih verzija
   - Ili sa servera: `docker compose -p netbird pull`

2. Ažuriraj pinned SHA digest u `docker-compose.yml` (ako je potrebno):
   ```bash
   docker compose -p netbird pull
   docker inspect netbirdio/netbird-server:latest --format='{{index .RepoDigests 0}}'
   # Kopiraj novi SHA256 u docker-compose.yml
   ```

3. Commit + push promjene u Git repo

4. Deploy:
   - Komodo UI → Pull repo → Deploy stack

### Dodavanje Novog Env Varijable

1. Dodaj varijablu u odgovarajući `.env` fajl na serveru (NE u repo):
   ```bash
   echo "NEW_VAR=value" >> /opt/stacks/netbird/dashboard.env
   ```

2. Referenciraj je u `docker-compose.yml` (ovo ide u repo):
   ```yaml
   environment:
     - NEW_VAR=${NEW_VAR}
   ```

3. Deployaj stack

## Backup

Cron backup job (`/opt/stacks/netbird/backup.sh`) radi nezavisno od Komodo-a
i koristi stabilne putanje:

```bash
# Ručni backup
sudo bash /opt/stacks/netbird/backup.sh

# Provjera backup logova
tail /var/log/netbird-backup.log
```

**Napomena:** Backup skripta i cron job nisu pod Komodo upravljanjem.
Putanje su nezavisne od Komodo Git checkouta.

## Rollback na Ručno Upravljanje

Ako trebaš privremeno ili trajno vratiti stack pod ručno upravljanje:

```bash
# 1. Stopiraj Komodo-managed stack
docker compose -p netbird stop

# 2. Pokreni ručno
cd /opt/stacks/netbird
docker compose -p netbird up -d

# 3. Provjeri
docker compose -p netbird ps
curl -s http://localhost:9000/health
```

Stack će nastaviti raditi identično — Komodo i ručni `docker compose`
koriste isti `project_name`, tako da nema konflikta.

## Troubleshooting

### Komodo ne vidi stack

```bash
# Provjeri da Periphery radi
systemctl status periphery

# Provjeri da Periphery ima pristup stack direktoriju
ls -la /opt/stacks/netbird/docker-compose.yml

# Provjeri Periphery logove
journalctl -u periphery -f
```

### Komodo kreira paralelni stack

Ako Komodo kreira novi stack umjesto da prepozna postojeći:

```bash
# Provjeri project_name u Komodo UI i na serveru
docker compose ls
docker inspect netbird-server --format '{{ index .Config.Labels "com.docker.compose.project" }}'

# Treba biti: netbird
# Ako nije, ažuriraj project_name u Komodo Stack konfiguraciji
```

### Secret fajlovi nestali nakon Git pull-a

**Ovo se ne bi trebalo desiti** — secret fajlovi su gitignored.

Ako se desi, restauriraj iz backupa:
```bash
# Pronađi najnoviji backup
ls -t /opt/stacks/netbird-pre-komodo-*

# Restauriraj
cp /opt/stacks/netbird-pre-komodo-*/config.yaml /opt/stacks/netbird/
cp /opt/stacks/netbird-pre-komodo-*/dashboard.env /opt/stacks/netbird/
cp /opt/stacks/netbird-pre-komodo-*/proxy.env /opt/stacks/netbird/

# Restartaj
docker compose -p netbird up -d
```

## Reference

- Komodo Docs: [https://komo.do](https://komo.do)
- Komodo Core: [https://komo-sso.imtec.ba](https://komo-sso.imtec.ba)
- Resource TOML: `resources/komodo-stack.toml`
- Migration Script: `scripts/komodo-migration.sh`
