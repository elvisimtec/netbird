# NetBird Database Reference

Internal reference for the NetBird server database structure, encryption,
and user management. Based on reverse-engineering of the production deployment.

---

## Database Files

| File | Purpose | Engine |
|------|---------|--------|
| `store.db` | Main NetBird data (users, peers, accounts, setup keys, policies, routes, groups, etc.) | SQLite |
| `idp.db` | Embedded OIDC identity provider (passwords, sessions, clients, connectors) | SQLite |
| `events.db` | Event/audit log | SQLite |
| `GeoIP2-City_*.mmdb` | MaxMind GeoIP database | Binary |
| `geonames_*.db` | GeoNames location database | SQLite |

Location: `/var/lib/docker/volumes/netbird_netbird_data/_data/`

---

## Encryption

### Algorithm

- **AES-256-GCM** with 12-byte random nonce
- Key stored in `config.yaml` as `store.encryptionKey` (base64-encoded)
- Active key: `4hSMGVN6iSZbGBT6bDiPxr2/CeDCQTmZdjqU4Ux/FC8=`

### Format

```
[12 bytes nonce] [ciphertext] [16 bytes GCM authentication tag]
```

Base64-encoded for storage in SQLite text columns.

### Encrypted Columns in `users` Table

| Column | Encrypted |
|--------|-----------|
| `name` | ✅ |
| `email` | ✅ |
| All other columns | ❌ plaintext |

### Python Decrypt Function

```python
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

key_b64 = '4hSMGVN6iSZbGBT6bDiPxr2/CeDCQTmZdjqU4Ux/FC8='
key = base64.b64decode(key_b64)
aesgcm = AESGCM(key)

def decrypt(b64data):
    raw = base64.b64decode(b64data)
    nonce = raw[:12]
    ct = raw[12:]
    return aesgcm.decrypt(nonce, ct, None).decode()

def encrypt(plaintext):
    nonce = os.urandom(12)
    ct = aesgcm.encrypt(nonce, plaintext.encode(), None)
    return base64.b64encode(nonce + ct).decode()
```

---

## OIDC Identity Provider (`idp.db`)

### Architecture

NetBird uses an embedded OIDC provider (dex-like). User credentials are
stored separately from the main NetBird data:

- `store.db/users` — NetBird user records (encrypted PII)
- `idp.db/password` — OIDC credentials (bcrypt hashes, plaintext email)
- `idp.db/user_identity` — OIDC identity mapping

### Tables

#### `password`

```sql
CREATE TABLE password (
    email text NOT NULL PRIMARY KEY,
    hash blob NOT NULL,          -- bcrypt hash
    username text NOT NULL,
    user_id text NOT NULL,       -- UUID
    preferred_username text DEFAULT '',
    groups blob DEFAULT '[]',    -- JSON array
    name text DEFAULT '',
    email_verified integer
);
```

Password hashing: **bcrypt** ($2b$12$)

#### `client`

```sql
CREATE TABLE client (
    id text NOT NULL PRIMARY KEY,
    secret text NOT NULL,
    redirect_uris blob NOT NULL,  -- JSON array
    trusted_peers blob NOT NULL,  -- JSON array
    public integer NOT NULL,
    name text NOT NULL,
    logo_url text NOT NULL
);
```

Registered clients:
| ID | Name | Public |
|----|------|--------|
| `netbird-dashboard` | NetBird Dashboard | Yes |
| `netbird-cli` | NetBird CLI | Yes |

#### `connector`

| ID | Type | Name |
|----|------|------|
| `local` | local | Email |

Only one connector: local email/password authentication.

#### Supported OIDC Grant Types

```
authorization_code
client_credentials      (confidential clients only)
refresh_token
urn:ietf:params:oauth:grant-type:device_code
urn:ietf:params:oauth:grant-type:token-exchange
```

**NOT supported:** `password` grant type.

#### Token Signing

- Algorithm: **RS256** (RSA)
- Key rotation: Supported (2 keys in `keys` table)

---

## User ID Format

The `users.id` in `store.db` is a protobuf-encoded message:

```
0a 24 <36-byte UUID string> 12 05 "local"
│  │                        │  │
│  └─ field 1: UUID         │  └─ field 2 value: "local"
└─ field 1 tag + length       └─ field 2 tag + length (5)
```

The same UUID is used as `user_id` in `idp.db/password`.

---

## User Management

### Creating a User (Manual via DB)

1. Generate UUID: `python3 -c "import uuid; print(uuid.uuid4())"`
2. Encrypt name and email with AES-256-GCM (see Python functions above)
3. Hash password with bcrypt: `bcrypt.hashpw(password.encode(), bcrypt.gensalt())`
4. Insert into `store.db/users` with protobuf-formatted ID
5. Insert into `idp.db/password`
6. Insert into `idp.db/user_identity`

### Current Users (as of 2026-07-30)

| Name | Email | Role | Created |
|------|-------|------|---------|
| Mirza H. | mirza.husejnovic@imtec.ba | owner | 2026-04-16 |
| Tehnička Podrška | tehnicka.podrska@imtec.ba | user | 2026-06-08 |
| admin | admin@imtec.ba | owner | 2026-07-30 |

---

## Dashboard Access

- URL: `https://netb.koorpa.ba`
- Auth: OIDC Authorization Code flow with PKCE
- Client: `netbird-dashboard` (public, no secret)
- OIDC Issuer: `https://netb.koorpa.ba/oauth2`

### Login Flow

```
Browser → Dashboard → Redirect to /oauth2/auth
→ User enters email/password
→ OIDC validates against idp.db
→ Redirect back to /nb-auth with auth code
→ Dashboard exchanges code for token
→ Authenticated session
```

---

## Important Notes

1. **NEVER commit `encryptionKey`** — it unlocks all user PII
2. **NEVER commit `idp.db`** — contains bcrypt hashes
3. **NEVER commit `.env`** — contains passwords and tokens
4. **encryptionKey rotation** is not straightforward after data exists —
   would require re-encrypting all encrypted columns
5. **Backup both `store.db` and `idp.db`** — they are interdependent
6. **Password reset** requires direct `idp.db` manipulation (no self-service yet)

---

## Common Pitfalls When Manually Creating Users

### Consents Column Format

The `consents` column in `idp.db/user_identity` **must be `{}`** (empty JSON object),
not `[]` (empty JSON array). Using `[]` causes:

```
ERRO select user identity: sql: Scan error on column index 8, name "consents":
unmarshal: json: cannot unmarshal array into Go value of type map[string][]string

ERRO failed to finalize login
```

**Symptoms:** "Internal Server Error" when attempting to log in with the new user.

**Fix:**
```sql
UPDATE user_identity SET consents = '{}' WHERE consents = '[]';
```

### `claims_groups` and `groups` Columns

Both `claims_groups` (in `user_identity`) and `groups` (in `password`) must be
**valid JSON arrays**. The existing users use `[]` (empty array) which is correct.
Do NOT use `''` (empty string) or `null`.

### `email_verified` Must Be Set

If `email_verified = 0`, the login may fail silently or redirect unexpectedly.
Set to `1` for manually created users:

```sql
UPDATE password SET email_verified = 1 WHERE email = 'user@example.com';
```

### Database Lock Contention

Both `store.db` and `idp.db` are accessed by the running NetBird server. When
making manual modifications:

1. **Use SQLite WAL mode** (enabled by default in NetBird)
2. **Never use exclusive locks** — use `BEGIN IMMEDIATE` for writes
3. **Backup both files before making changes**
4. **No server restart needed** — changes are picked up immediately

---

## Troubleshooting

### User can't log in — "Internal Server Error"

1. Check `consents` format: `sqlite3 idp.db "SELECT consents FROM user_identity WHERE claims_email='user@example.com';"`
   - Must be `{}`, not `[]`
2. Check server logs: `docker logs netbird-server | grep -i "failed to"`
3. Verify both `store.db/users` and `idp.db/password` have matching `user_id` values
4. Verify the user exists in both databases

### User can't log in — "Invalid email or password"

1. Verify bcrypt hash is valid: Python `bcrypt.checkpw()` test
2. Check `idp.db/password` has correct `email` and `hash`
3. Verify `connector` table has `local` entry with `type='local'`

---

## Related

- [Architecture](architecture.md)
- [Configuration Reference](configuration.md)
- [Backup and Restore](operations/backup-restore.md)
- [Security Hardening](security/hardening.md)
